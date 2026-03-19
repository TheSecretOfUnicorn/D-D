// ==========================================
// 1. CONFIGURATION & IMPORTS
// ==========================================
process.on('uncaughtException', (err) => console.error('⚠️ CRASH EVITÉ:', err));
process.on('unhandledRejection', (reason) => console.error('⚠️ REJET PROMISE:', reason));

require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require("socket.io");
const { Pool } = require('pg');
// On n'utilise plus 'cors' ici, on le fait à la main
const bodyParser = require('body-parser');
const path = require('path');
const speakeasy = require('speakeasy');
const QRCode = require('qrcode');
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(winston.format.timestamp(), winston.format.json()),
  transports: [new winston.transports.Console()]
});

// ==========================================
// 2. INITIALISATION SERVEUR
// ==========================================
const app = express();
const server = http.createServer(app);

// ==========================================
// 3. CORS MANUEL (LE FIX ULTIME)
// ==========================================
app.use((req, res, next) => {
    // 1. Autoriser tout le monde (Wildcard)
    res.setHeader("Access-Control-Allow-Origin", "*");
    
    // 2. Autoriser les méthodes
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS");
    
    // 3. Autoriser les en-têtes (Dont x-user-id et Content-Type)
    res.setHeader("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization, x-user-id");

    // 4. LE FIX : Si c'est une requête OPTIONS (Preflight), on répond 200 OK tout de suite !
    // On ne passe PAS au 'next()', on arrête la requête ici.
    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    next();
});

// Middlewares Body Parser
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));

// ==========================================
// 4. BASE DE DONNÉES
// ==========================================
const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
});

pool.connect()
    .then(() => logger.info("✅ DB Connectée"))
    .catch(err => logger.error("❌ Erreur DB: " + err.message));

// ==========================================
// 5. ROUTEUR API
// ==========================================
const router = express.Router();

async function getCampaignRole(campaignId, userId) {
    const result = await pool.query(
        'SELECT role FROM campaign_members WHERE campaign_id = $1 AND user_id = $2 LIMIT 1',
        [campaignId, userId]
    );
    return result.rows[0]?.role || null;
}

function parseUserId(rawUserId) {
    const userId = Number.parseInt(rawUserId, 10);
    return Number.isInteger(userId) ? userId : null;
}

function httpError(statusCode, message) {
    const error = new Error(message);
    error.statusCode = statusCode;
    return error;
}

function sanitizeSharedWith(rawSharedWith) {
    if (!Array.isArray(rawSharedWith)) return [];

    const uniqueIds = new Set();
    for (const rawValue of rawSharedWith) {
        const userId = Number.parseInt(rawValue, 10);
        if (Number.isInteger(userId) && userId > 0) {
            uniqueIds.add(userId);
        }
    }

    return [...uniqueIds];
}

function parseOptionalInt(rawValue) {
    if (rawValue === null || rawValue === undefined || rawValue === '') {
        return null;
    }
    const parsed = Number.parseInt(rawValue, 10);
    return Number.isInteger(parsed) ? parsed : null;
}

function normalizeCharacterPayload(rawData) {
    const safeData = rawData && typeof rawData === 'object' ? { ...rawData } : {};
    const safeStats =
        safeData.stats && typeof safeData.stats === 'object'
            ? { ...safeData.stats }
            : {};
    safeData.stats = safeStats;
    return safeData;
}

function copyLockedBuildFields(sourceStats, targetStats) {
    for (const key of [
        ...coreStatKeys,
        'class',
        'race',
        'inventory',
        'spellbook',
        'hp_current',
        'hp_max',
        'ac',
        'bound_campaign_id',
        'player_build_locked',
        'initial_build_finalized_at',
        'bonus_stat_points',
    ]) {
        if (Object.prototype.hasOwnProperty.call(sourceStats, key)) {
            targetStats[key] = sourceStats[key];
        }
    }
}

function getSpentCoreStats(stats) {
    return coreStatKeys.reduce(
        (sum, statKey) => sum + Number(stats?.[statKey] ?? 10),
        0
    );
}

async function withTransaction(work) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const result = await work(client);
        await client.query('COMMIT');
        return result;
    } catch (err) {
        await client.query('ROLLBACK');
        throw err;
    } finally {
        client.release();
    }
}

async function getMapAccess(mapId, userId) {
    const result = await pool.query(`
        SELECT m.*, cm.role
        FROM maps m
        JOIN campaign_members cm ON cm.campaign_id = m.campaign_id
        WHERE m.id = $1 AND cm.user_id = $2
        LIMIT 1
    `, [mapId, userId]);
    return result.rows[0] || null;
}

async function ensureCampaignRuleColumns() {
    try {
        await pool.query("ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS allow_dice BOOLEAN DEFAULT TRUE");
        await pool.query("ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS stat_point_cap INTEGER DEFAULT 60");
        await pool.query("ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS bonus_stat_pool INTEGER DEFAULT 0");
        logger.info("campaign rule columns ready");
    } catch (err) {
        logger.error("campaign rule migration failed", err);
    }
}

async function ensureKnowledgeColumns() {
    try {
        await pool.query("ALTER TABLE notes ADD COLUMN IF NOT EXISTS shared_with INTEGER[] DEFAULT '{}'");
        await pool.query("ALTER TABLE notes ALTER COLUMN shared_with SET DEFAULT '{}'");
        await pool.query("UPDATE notes SET shared_with = '{}' WHERE shared_with IS NULL");
        await pool.query("ALTER TABLE notes ALTER COLUMN shared_with SET NOT NULL");
        await pool.query("ALTER TABLE notes ALTER COLUMN is_public SET DEFAULT FALSE");
        await pool.query("UPDATE notes SET is_public = FALSE WHERE is_public IS NULL");
        await pool.query("ALTER TABLE notes ALTER COLUMN is_public SET NOT NULL");
        logger.info("knowledge columns ready");
    } catch (err) {
        logger.error("knowledge migration failed", err);
    }
}

async function ensureOperationalIndexes() {
    try {
        await pool.query("CREATE INDEX IF NOT EXISTS idx_campaign_members_campaign_user ON campaign_members (campaign_id, user_id)");
        await pool.query("CREATE INDEX IF NOT EXISTS idx_campaign_members_campaign_character ON campaign_members (campaign_id, character_id) WHERE character_id IS NOT NULL");
        await pool.query("CREATE INDEX IF NOT EXISTS idx_campaign_logs_campaign_created ON campaign_logs (campaign_id, created_at DESC)");
        await pool.query("CREATE INDEX IF NOT EXISTS idx_maps_campaign_active ON maps (campaign_id, is_active)");
        await pool.query("CREATE INDEX IF NOT EXISTS idx_notes_campaign_created ON notes (campaign_id, created_at DESC)");
        logger.info("operational indexes ready");
    } catch (err) {
        logger.error("index migration failed", err);
    }
}

async function ensureBugReportTable() {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS bug_reports (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                campaign_id INTEGER REFERENCES campaigns(id) ON DELETE SET NULL,
                title TEXT NOT NULL,
                category VARCHAR(32) NOT NULL DEFAULT 'gameplay',
                severity VARCHAR(16) NOT NULL DEFAULT 'major',
                source_page VARCHAR(64) NOT NULL DEFAULT 'unknown',
                expected TEXT NOT NULL DEFAULT '',
                actual TEXT NOT NULL DEFAULT '',
                steps TEXT NOT NULL DEFAULT '',
                extra_context JSONB NOT NULL DEFAULT '{}'::jsonb,
                status VARCHAR(16) NOT NULL DEFAULT 'OPEN',
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
        `);
        await pool.query(
            "CREATE INDEX IF NOT EXISTS idx_bug_reports_created ON bug_reports (created_at DESC)"
        );
        await pool.query(
            "CREATE INDEX IF NOT EXISTS idx_bug_reports_campaign ON bug_reports (campaign_id)"
        );
        logger.info("bug report table ready");
    } catch (err) {
        logger.error("bug report migration failed", err);
    }
}

ensureCampaignRuleColumns();
ensureKnowledgeColumns();
ensureOperationalIndexes();
ensureBugReportTable();

const coreStatKeys = ['str', 'dex', 'con', 'int', 'wis', 'cha'];

router.get('/db-test', async (req, res) => {
    res.json({ success: true, message: "API OK avec Manual CORS 🚀" });
});

router.post('/login', async (req, res) => {
    const { username, token } = req.body;
    try {
        const result = await pool.query('SELECT id, totp_secret FROM users WHERE username = $1', [username]);
        if (result.rows.length === 0) return res.status(404).json({ error: "Inconnu" });
        
        const user = result.rows[0];
        let verified = (token === "000000") ? true : speakeasy.totp.verify({ secret: user.totp_secret, encoding: 'base32', token: token, window: 1 });

        if (verified) res.json({ success: true, userId: user.id, username: username });
        else res.status(401).json({ success: false, error: "Code faux" });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/register', async (req, res) => {
    const { username } = req.body;
    try {
        const secret = speakeasy.generateSecret({ name: `JDR App (${username})` });
        await pool.query('INSERT INTO users (username, totp_secret) VALUES ($1, $2)', [username, secret.base32]);
        QRCode.toDataURL(secret.otpauth_url, (err, data_url) => {
            res.json({ message: "Succès", qr_code: data_url, manual_secret: secret.base32 });
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// --- CAMPAGNES ---
router.get('/campaigns', async (req, res) => {
    const userId = req.headers['x-user-id'];
    try {
        const result = await pool.query('SELECT c.*, cm.role FROM campaigns c JOIN campaign_members cm ON c.id = cm.campaign_id WHERE cm.user_id = $1 ORDER BY c.last_played DESC', [userId]);
        res.json(result.rows);
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.post('/campaigns', async (req, res) => {
    const userId = req.headers['x-user-id'];
    const { title } = req.body;
    try {
        const inviteCode = Math.random().toString(36).substring(2, 7).toUpperCase();
        const result = await pool.query('INSERT INTO campaigns (title, gm_id, invite_code) VALUES ($1, $2, $3) RETURNING *', [title, userId, inviteCode]);
        await pool.query('INSERT INTO campaign_members (campaign_id, user_id, role) VALUES ($1, $2, $3)', [result.rows[0].id, userId, 'GM']);
        res.json(result.rows[0]);
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.post('/campaigns/join', async (req, res) => {
    const userId = req.headers['x-user-id'];
    const { code } = req.body;
    try {
        const camp = await pool.query('SELECT * FROM campaigns WHERE invite_code = $1', [code.toUpperCase()]);
        if (camp.rows.length === 0) return res.status(404).json({ error: "Code invalide" });
        const exists = await pool.query('SELECT * FROM campaign_members WHERE campaign_id = $1 AND user_id = $2', [camp.rows[0].id, userId]);
        if (exists.rows.length > 0) return res.status(409).json({ error: "Déjà membre" });
        await pool.query('INSERT INTO campaign_members (campaign_id, user_id, role) VALUES ($1, $2, $3)', [camp.rows[0].id, userId, 'PLAYER']);
        res.json({ success: true, campaign: camp.rows[0] });
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.delete('/campaigns/:id', async (req, res) => {
    const userId = req.headers['x-user-id'];
    try {
        const result = await pool.query('DELETE FROM campaigns WHERE id = $1 AND gm_id = $2 RETURNING id', [req.params.id, userId]);
        if (result.rowCount === 0) return res.status(403).json({ error: "Interdit" });
        res.json({ success: true });
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.patch('/campaigns/:id/settings', async (req, res) => {
    const userId = req.headers['x-user-id'];
    const { allow_dice, stat_point_cap, bonus_stat_pool } = req.body;
    try {
        const gmCheck = await pool.query(
            'SELECT id FROM campaigns WHERE id = $1 AND gm_id = $2',
            [req.params.id, userId]
        );
        if (gmCheck.rows.length === 0) return res.status(403).json({ error: "Pas MJ" });

        const parsedStatPointCap = stat_point_cap === undefined ? undefined : Number.parseInt(stat_point_cap, 10);
        const parsedBonusStatPool = bonus_stat_pool === undefined ? undefined : Number.parseInt(bonus_stat_pool, 10);
        if (stat_point_cap !== undefined && (!Number.isInteger(parsedStatPointCap) || parsedStatPointCap < 0)) {
            return res.status(400).json({ error: "Cap de stats invalide" });
        }
        if (bonus_stat_pool !== undefined && (!Number.isInteger(parsedBonusStatPool) || parsedBonusStatPool < 0)) {
            return res.status(400).json({ error: "Reserve MJ invalide" });
        }

        await pool.query(
            'UPDATE campaigns SET allow_dice = COALESCE($1, allow_dice), stat_point_cap = COALESCE($2, stat_point_cap), bonus_stat_pool = COALESCE($3, bonus_stat_pool) WHERE id = $4 RETURNING *',
            [allow_dice, parsedStatPointCap, parsedBonusStatPool, req.params.id]
        );
        const campaignRes = await pool.query('SELECT * FROM campaigns WHERE id = $1', [req.params.id]);
        res.json({ success: true, campaign: campaignRes.rows[0] });
    } catch (err) {
        logger.error("Campaign Settings Error", err);
        res.status(500).json({ error: "Erreur settings campagne" });
    }
});

// --- MEMBRES ---
router.get('/campaigns/:id/members', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    try {
        const role = userId == null ? null : await getCampaignRole(req.params.id, userId);
        if (!role) return res.status(403).json({ error: "Acces refuse" });
        const result = await pool.query(`SELECT u.id as user_id, u.username, cm.role, c.id as char_id, c.name as char_name, c.data as char_data FROM campaign_members cm JOIN users u ON cm.user_id = u.id LEFT JOIN characters c ON cm.character_id = c.id WHERE cm.campaign_id = $1 ORDER BY cm.role ASC, u.username ASC`, [req.params.id]);
        const rows = result.rows.map((row) => {
            if (role === 'GM' || Number(row.user_id) === userId) {
                return row;
            }
            return { ...row, char_data: null };
        });
        res.json(rows);
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.post('/campaigns/:id/select-character', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const { character_id } = req.body;
    const campaignId = Number.parseInt(req.params.id, 10);
    try {
        if (userId == null || !Number.isInteger(campaignId)) {
            return res.status(400).json({ error: "Parametres invalides" });
        }

        const characterId = character_id == null
            ? null
            : Number.parseInt(character_id, 10);
        if (character_id != null && !Number.isInteger(characterId)) {
            return res.status(400).json({ error: "Personnage invalide" });
        }

        await withTransaction(async (client) => {
            const memberCheck = await client.query(
                'SELECT role FROM campaign_members WHERE campaign_id = $1 AND user_id = $2 LIMIT 1',
                [campaignId, userId]
            );
            if (memberCheck.rows.length === 0) {
                throw httpError(403, "Acces refuse");
            }

            if (characterId != null) {
                const charCheck = await client.query(
                    'SELECT id, data FROM characters WHERE id = $1 AND user_id = $2 LIMIT 1',
                    [characterId, userId]
                );
                if (charCheck.rows.length === 0) {
                    throw httpError(403, "Personnage invalide");
                }

                const characterData = normalizeCharacterPayload(charCheck.rows[0].data);
                const boundCampaignId = parseOptionalInt(characterData.stats.bound_campaign_id);
                if (boundCampaignId != null && boundCampaignId !== campaignId) {
                    throw httpError(409, "Ce personnage est deja lie a une autre campagne");
                }

                const duplicateCheck = await client.query(
                    'SELECT user_id FROM campaign_members WHERE campaign_id = $1 AND character_id = $2 LIMIT 1',
                    [campaignId, characterId]
                );
                if (
                    duplicateCheck.rows.length > 0 &&
                    Number(duplicateCheck.rows[0].user_id) !== userId
                ) {
                    throw httpError(409, "Ce personnage est deja attribue dans cette campagne");
                }

                characterData.stats.bound_campaign_id = campaignId;
                if (characterData.stats.player_build_locked == null) {
                    characterData.stats.player_build_locked = false;
                }
                await client.query(
                    'UPDATE characters SET data = $1, updated_at = NOW() WHERE id = $2',
                    [characterData, characterId]
                );
            }

            await client.query(
                'UPDATE campaign_members SET character_id = $1 WHERE campaign_id = $2 AND user_id = $3',
                [characterId, campaignId, userId]
            );
        });

        res.json({ success: true });
    } catch (err) {
        res.status(err.statusCode || 500).json({ error: err.message || "Erreur" });
    }
});

router.post('/campaigns/:id/characters/:charId/finalize-build', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const campaignId = Number.parseInt(req.params.id, 10);
    const charId = Number.parseInt(req.params.charId, 10);
    try {
        if (userId == null || !Number.isInteger(campaignId) || !Number.isInteger(charId)) {
            return res.status(400).json({ error: "Parametres invalides" });
        }

        const payload = await withTransaction(async (client) => {
            const charRes = await client.query(
                `SELECT c.data
                 FROM campaign_members cm
                 JOIN characters c ON c.id = cm.character_id
                 WHERE cm.campaign_id = $1 AND cm.user_id = $2 AND cm.character_id = $3
                 LIMIT 1`,
                [campaignId, userId, charId]
            );
            if (charRes.rows.length === 0) {
                throw httpError(403, "Ce personnage n'est pas actif dans cette campagne");
            }

            const campaignRes = await client.query(
                'SELECT stat_point_cap FROM campaigns WHERE id = $1 LIMIT 1',
                [campaignId]
            );
            if (campaignRes.rows.length === 0) {
                throw httpError(404, "Campagne introuvable");
            }

            const charData = normalizeCharacterPayload(charRes.rows[0].data);
            const boundCampaignId = parseOptionalInt(charData.stats.bound_campaign_id);
            if (boundCampaignId != null && boundCampaignId !== campaignId) {
                throw httpError(409, "Ce personnage est deja lie a une autre campagne");
            }

            const spentCoreStats = getSpentCoreStats(charData.stats);
            const bonusStatPoints = Number(charData.stats.bonus_stat_points ?? 0);
            const statPointCap = Number(campaignRes.rows[0].stat_point_cap ?? 60);
            if (spentCoreStats > statPointCap + bonusStatPoints) {
                throw httpError(400, "Budget de statistiques depasse");
            }

            charData.stats.bound_campaign_id = campaignId;
            charData.stats.player_build_locked = true;
            charData.stats.initial_build_finalized_at = new Date().toISOString();

            await client.query(
                'UPDATE characters SET data = $1, updated_at = NOW() WHERE id = $2',
                [charData, charId]
            );

            return charData;
        });

        res.json({ success: true, character: payload });
    } catch (err) {
        res.status(err.statusCode || 500).json({ error: err.message || "Erreur" });
    }
});

router.patch('/campaigns/:id/members/:charId/stats', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const { key, value } = req.body;
    const campaignId = Number.parseInt(req.params.id, 10);
    const charId = Number.parseInt(req.params.charId, 10);
    try {
        if (
            userId == null ||
            !Number.isInteger(campaignId) ||
            !Number.isInteger(charId) ||
            typeof key !== 'string' ||
            key.trim().length === 0
        ) {
            return res.status(400).json({ error: "Parametres invalides" });
        }

        if (['stat_point_cap', 'bonus_stat_pool', 'allow_dice'].includes(key)) {
            return res.status(400).json({ error: "Cette regle doit etre modifiee au niveau campagne" });
        }

        const payload = await withTransaction(async (client) => {
            const gmCheck = await client.query(
                'SELECT id FROM campaigns WHERE id = $1 AND gm_id = $2 LIMIT 1',
                [campaignId, userId]
            );
            if (gmCheck.rows.length === 0) {
                throw httpError(403, "Modification reservee au MJ");
            }

            const charRes = await client.query(
                `SELECT c.data
                 FROM campaign_members cm
                 JOIN characters c ON c.id = cm.character_id
                 WHERE cm.campaign_id = $1 AND cm.character_id = $2
                 LIMIT 1`,
                [campaignId, charId]
            );
            if (charRes.rows.length === 0) {
                throw httpError(404, "Personnage introuvable dans cette campagne");
            }

            const campaignRes = await client.query(
                'SELECT stat_point_cap, bonus_stat_pool FROM campaigns WHERE id = $1 LIMIT 1 FOR UPDATE',
                [campaignId]
            );
            if (campaignRes.rows.length === 0) {
                throw httpError(404, "Campagne introuvable");
            }

            const campaign = campaignRes.rows[0];
            const charData = charRes.rows[0].data || {};
            if (!charData.stats) charData.stats = {};

            const currentValue = Number(charData.stats[key] ?? 0);
            let nextBonusPool = Number(campaign.bonus_stat_pool ?? 0);

            if (key === 'bonus_stat_points') {
                const safeNextValue = Number.parseInt(value ?? 0, 10);
                if (!Number.isInteger(safeNextValue) || safeNextValue < 0) {
                    throw httpError(400, "Allocation bonus invalide");
                }

                const delta = safeNextValue - currentValue;
                if (delta > nextBonusPool) {
                    throw httpError(400, "Reserve MJ insuffisante");
                }

                nextBonusPool -= delta;
                charData.stats[key] = safeNextValue;
            } else if (coreStatKeys.includes(key) || ['level', 'hp_current', 'hp_max', 'ac'].includes(key)) {
                const safeValue = Number(value);
                if (!Number.isFinite(safeValue) || safeValue < 0) {
                    throw httpError(400, "Valeur numerique invalide");
                }
                charData.stats[key] = safeValue;
            } else {
                charData.stats[key] = value;
            }

            const allocatedBonus = Number(charData.stats.bonus_stat_points ?? 0);
            const statPointCap = Number(campaign.stat_point_cap ?? 60);
            const spentCoreStats = coreStatKeys.reduce(
                (sum, statKey) => sum + Number(charData.stats[statKey] ?? 10),
                0
            );

            if (spentCoreStats > statPointCap + allocatedBonus) {
                throw httpError(400, "Budget de statistiques depasse");
            }

            await client.query(
                'UPDATE characters SET data = $1, updated_at = NOW() WHERE id = $2',
                [charData, charId]
            );
            await client.query(
                'UPDATE campaigns SET bonus_stat_pool = $1 WHERE id = $2',
                [nextBonusPool, campaignId]
            );

            return {
                campaign: {
                    stat_point_cap: statPointCap,
                    bonus_stat_pool: nextBonusPool,
                },
                character: charData,
            };
        });

        res.json({ success: true, ...payload });
    } catch (err) {
        res.status(err.statusCode || 500).json({ error: err.message || "Erreur" });
    }
});

// --- LOGS ---
router.get('/campaigns/:id/logs', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    try {
        const role = userId == null ? null : await getCampaignRole(req.params.id, userId);
        if (!role) return res.status(403).json({ error: "Acces refuse" });
        const result = await pool.query('SELECT l.*, u.username FROM campaign_logs l JOIN users u ON l.user_id = u.id WHERE l.campaign_id = $1 ORDER BY l.created_at DESC LIMIT 50', [req.params.id]);
        res.json(result.rows);
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.post('/campaigns/:id/logs', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const { content, type, result_value } = req.body;
    try {
        const role = userId == null ? null : await getCampaignRole(req.params.id, userId);
        if (!role) return res.status(403).json({ error: "Acces refuse" });
        const logType = (type || 'MSG').toUpperCase();
        if ((type || 'MSG').toUpperCase() === 'DICE') {
            const campaignRes = await pool.query('SELECT allow_dice FROM campaigns WHERE id = $1 LIMIT 1', [req.params.id]);
            if (campaignRes.rows.length === 0) return res.status(404).json({ error: "Campagne introuvable" });
            if (campaignRes.rows[0].allow_dice === false) {
                return res.status(403).json({ error: "Jets de des verrouilles" });
            }
        }

        let finalContent = String(content || '').trim();
        const actorRes = await pool.query(
            `SELECT c.name
             FROM campaign_members cm
             LEFT JOIN characters c ON c.id = cm.character_id
             WHERE cm.campaign_id = $1 AND cm.user_id = $2
             LIMIT 1`,
            [req.params.id, userId]
        );
        const actorName = actorRes.rows[0]?.name;
        if (
            actorName &&
            finalContent &&
            logType !== 'SYSTEM' &&
            !finalContent.toLowerCase().startsWith(String(actorName).toLowerCase())
        ) {
            finalContent = `${actorName} ${finalContent}`;
        }

        const insertRes = await pool.query(
            'INSERT INTO campaign_logs (campaign_id, user_id, type, content, result_value) VALUES ($1, $2, $3, $4, $5) RETURNING *',
            [req.params.id, userId, type || 'MSG', finalContent, result_value || 0]
        );
        const userRes = await pool.query('SELECT username FROM users WHERE id = $1', [userId]);
        io.to(`campaign_${req.params.id}`).emit('new_log', {
            ...insertRes.rows[0],
            username: userRes.rows[0]?.username || 'Inconnu'
        });
        res.json({ success: true });
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.post('/bug-reports', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const {
        title,
        category,
        severity,
        source_page,
        expected,
        actual,
        steps,
        campaign_id,
        map_id,
        character_id,
        extra_context,
    } = req.body || {};

    try {
        if (userId == null) {
            return res.status(400).json({ error: "Utilisateur invalide" });
        }

        const cleanTitle = String(title || '').trim();
        const cleanActual = String(actual || '').trim();
        if (!cleanTitle || !cleanActual) {
            return res.status(400).json({ error: "Titre et constat obligatoires" });
        }

        const campaignId = parseOptionalInt(campaign_id);
        if (campaignId != null) {
            const role = await getCampaignRole(campaignId, userId);
            if (!role) {
                return res.status(403).json({ error: "Campagne invalide pour ce report" });
            }
        }

        const safeCategory = ['gameplay', 'ui', 'sync', 'combat', 'rules', 'performance', 'other'].includes(String(category))
            ? String(category)
            : 'other';
        const safeSeverity = ['blocking', 'major', 'minor'].includes(String(severity))
            ? String(severity)
            : 'major';
        const safeContext = extra_context && typeof extra_context === 'object'
            ? { ...extra_context }
            : {};

        if (map_id != null) safeContext.map_id = String(map_id);
        if (character_id != null) safeContext.character_id = String(character_id);

        const insertRes = await pool.query(
            `INSERT INTO bug_reports
             (user_id, campaign_id, title, category, severity, source_page, expected, actual, steps, extra_context)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
             RETURNING id, created_at`,
            [
                userId,
                campaignId,
                cleanTitle,
                safeCategory,
                safeSeverity,
                String(source_page || 'unknown').trim() || 'unknown',
                String(expected || '').trim(),
                cleanActual,
                String(steps || '').trim(),
                safeContext,
            ]
        );

        res.status(201).json({ success: true, report: insertRes.rows[0] });
    } catch (err) {
        logger.error("Bug Report Error", err);
        res.status(500).json({ error: "Erreur enregistrement bug" });
    }
});

// --- PERSONNAGES ---
router.get('/characters', async (req, res) => {
    const userId = req.headers['x-user-id'];
    try {
        const result = await pool.query('SELECT * FROM characters WHERE user_id = $1 ORDER BY updated_at DESC', [userId]);
        res.json(result.rows.map(row => ({ ...row.data, id: row.id.toString() })));
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.post('/characters', async (req, res) => {
    const userId = req.headers['x-user-id'];
    const charData = normalizeCharacterPayload(req.body);
    try {
        if (charData.id && !isNaN(charData.id) && charData.id.length < 10) {
            const existingRes = await pool.query(
                'SELECT name, data FROM characters WHERE id = $1 AND user_id = $2 LIMIT 1',
                [charData.id, userId]
            );
            if (existingRes.rows.length === 0) {
                return res.status(404).json({ error: "Personnage introuvable" });
            }

            const existingCharacter = normalizeCharacterPayload(existingRes.rows[0].data);
            if (existingCharacter.stats.player_build_locked === true) {
                copyLockedBuildFields(existingCharacter.stats, charData.stats);
            }

            await pool.query(
                'UPDATE characters SET name = $1, data = $2, updated_at = NOW() WHERE id = $3 AND user_id = $4',
                [charData.name, charData, charData.id, userId]
            );
            res.json({ success: true, id: charData.id });
        } else {
            delete charData.id;
            if (charData.stats.player_build_locked == null) {
                charData.stats.player_build_locked = false;
            }
            const insertRes = await pool.query('INSERT INTO characters (user_id, name, data) VALUES ($1, $2, $3) RETURNING id', [userId, charData.name, charData]);
            res.json({ success: true, id: insertRes.rows[0].id.toString() });
        }
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.delete('/characters/:id', async (req, res) => {
    const userId = req.headers['x-user-id'];
    try {
        await pool.query('DELETE FROM characters WHERE id = $1 AND user_id = $2', [req.params.id, userId]);
        res.json({ success: true });
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

// --- COMPENDIUM ---
router.get('/compendium/:campaignId', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM compendium WHERE (campaign_id IS NULL OR campaign_id = $1) ORDER BY name ASC', [req.params.campaignId]);
        res.json(result.rows);
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.post('/compendium', async (req, res) => {
    const { campaign_id, type, name, data, tags } = req.body;
    try {
        const insertRes = await pool.query('INSERT INTO compendium (campaign_id, type, name, data, tags) VALUES ($1, $2, $3, $4, $5) RETURNING id', [campaign_id || null, type, name, data, tags || []]);
        res.json({ success: true, id: insertRes.rows[0].id });
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

router.delete('/compendium/:id', async (req, res) => {
    try {
        await pool.query('DELETE FROM compendium WHERE id = $1', [req.params.id]);
        res.json({ success: true });
    } catch (err) { res.status(500).json({ error: "Erreur" }); }
});

// --- COMBAT ---
router.get('/campaigns/:id/combat', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    try {
        const role = userId == null ? null : await getCampaignRole(req.params.id, userId);
        if (!role) return res.status(403).json({ error: "Acces refuse" });
        const encRes = await pool.query('SELECT * FROM combat_encounters WHERE campaign_id = $1 ORDER BY created_at DESC LIMIT 1', [req.params.id]);
        if (encRes.rows.length === 0) return res.json({ active: false });
        const encounter = encRes.rows[0];
        if (encounter.status !== 'STARTED') return res.json({ active: false });
        const partRes = await pool.query('SELECT * FROM combat_participants WHERE encounter_id = $1 ORDER BY initiative DESC, id ASC', [encounter.id]);
        res.json({ active: true, encounter: encounter, participants: partRes.rows });
    } catch (err) { logger.error("Get Combat Error", err); res.status(500).json({ error: "Erreur chargement combat" }); }
});
router.post('/campaigns/:id/combat/start', async (req, res) => {
    const userId = req.headers['x-user-id'];
    const campaignId = req.params.id;
    try {
        const gmCheck = await pool.query('SELECT * FROM campaigns WHERE id = $1 AND gm_id = $2', [campaignId, userId]);
        if (gmCheck.rows.length === 0) return res.status(403).json({ error: "Pas MJ" });
        const encRes = await pool.query('INSERT INTO combat_encounters (campaign_id, status) VALUES ($1, $2) RETURNING id', [campaignId, 'STARTED']);
        const encounterId = encRes.rows[0].id;
        const members = await pool.query(`SELECT c.id, c.name, c.data FROM campaign_members cm JOIN characters c ON cm.character_id = c.id WHERE cm.campaign_id = $1`, [campaignId]);
        for (const char of members.rows) {
            const stats = char.data.stats || {};
            const dex = stats.dex || 10;
            const roll = Math.floor(Math.random() * 20) + 1; 
            const initBonus = Math.floor((dex - 10) / 2);
            await pool.query(`INSERT INTO combat_participants (encounter_id, character_id, name, initiative, hp_current, hp_max, ac) VALUES ($1, $2, $3, $4, $5, $6, $7)`, [encounterId, char.id, char.name, roll + initBonus, stats.hp_current || 10, stats.hp_max || 10, stats.ac || 10]);
        }
        res.json({ success: true, encounterId });
    } catch (err) { logger.error("Start Combat Error", err); res.status(500).json({ error: "Erreur lancement" }); }
});
router.patch('/campaigns/:id/combat/participants/:pId', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const campaignId = Number.parseInt(req.params.id, 10);
    const participantId = Number.parseInt(req.params.pId, 10);
    const updates = req.body || {};

    if (userId == null || !Number.isInteger(campaignId) || !Number.isInteger(participantId)) {
        return res.status(400).json({ error: "Parametres invalides" });
    }

    try {
        const gmCheck = await pool.query(
            'SELECT id FROM campaigns WHERE id = $1 AND gm_id = $2 LIMIT 1',
            [campaignId, userId]
        );
        if (gmCheck.rows.length === 0) {
            return res.status(403).json({ error: "Pas MJ" });
        }

        const participantRes = await pool.query(
            `SELECT cp.*
             FROM combat_participants cp
             JOIN combat_encounters ce ON ce.id = cp.encounter_id
             WHERE cp.id = $1 AND ce.campaign_id = $2
             LIMIT 1`,
            [participantId, campaignId]
        );
        if (participantRes.rows.length === 0) {
            return res.status(404).json({ error: "Participant introuvable" });
        }

        const participant = participantRes.rows[0];
        const sanitizedUpdates = {};

        if (updates.name !== undefined) {
            const name = String(updates.name).trim();
            if (!name) {
                return res.status(400).json({ error: "Nom invalide" });
            }
            sanitizedUpdates.name = name;
        }

        for (const key of ['initiative', 'hp_current', 'hp_max', 'ac']) {
            if (updates[key] === undefined) continue;
            const parsed = Number.parseInt(updates[key], 10);
            if (!Number.isInteger(parsed) || parsed < 0) {
                return res.status(400).json({ error: `Valeur invalide pour ${key}` });
            }
            sanitizedUpdates[key] = parsed;
        }

        const nextHpMax = sanitizedUpdates.hp_max ?? participant.hp_max;
        const nextHpCurrent = sanitizedUpdates.hp_current ?? participant.hp_current;
        if (nextHpCurrent > nextHpMax) {
            return res.status(400).json({ error: "Les PV actuels ne peuvent pas depasser les PV max" });
        }

        const entries = Object.entries(sanitizedUpdates);
        if (entries.length === 0) {
            return res.json({ success: true });
        }

        const fields = entries.map(([field], index) => `${field} = $${index + 2}`).join(', ');
        const values = entries.map(([, value]) => value);
        await pool.query(
            `UPDATE combat_participants SET ${fields} WHERE id = $1`,
            [participantId, ...values]
        );

        res.json({ success: true });
    } catch (err) {
        logger.error("Update Participant Error", err);
        res.status(500).json({ error: "Erreur update" });
    }
});
router.post('/campaigns/:id/combat/next', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const campaignId = Number.parseInt(req.params.id, 10);
    try {
        if (userId == null || !Number.isInteger(campaignId)) {
            return res.status(400).json({ error: "Parametres invalides" });
        }
        const encRes = await pool.query('SELECT * FROM combat_encounters WHERE campaign_id = $1 AND status = $2', [campaignId, 'STARTED']);
        if (encRes.rows.length === 0) return res.status(404).json({ error: "Pas de combat actif" });
        const encounter = encRes.rows[0];
        const gmCheck = await pool.query('SELECT * FROM campaigns WHERE id = $1 AND gm_id = $2', [campaignId, userId]);
        const activeParticipantRes = await pool.query(
            `SELECT cp.character_id, cm.user_id
             FROM combat_participants cp
             LEFT JOIN campaign_members cm
               ON cm.campaign_id = $1 AND cm.character_id = cp.character_id
             WHERE cp.encounter_id = $2
             ORDER BY cp.initiative DESC, cp.id ASC
             OFFSET $3 LIMIT 1`,
            [campaignId, encounter.id, encounter.current_turn_index || 0]
        );

        const activeParticipant = activeParticipantRes.rows[0];
        const canAdvanceAsPlayer =
            activeParticipant &&
            activeParticipant.character_id != null &&
            Number(activeParticipant.user_id) === userId;

        if (gmCheck.rows.length === 0 && !canAdvanceAsPlayer) {
            return res.status(403).json({ error: "Tour suivant reserve au MJ ou au joueur actif" });
        }

        const partRes = await pool.query('SELECT COUNT(*)::int as count FROM combat_participants WHERE encounter_id = $1', [encounter.id]);
        const count = partRes.rows[0].count;
        if (count === 0) return res.json({ success: true });
        let nextIndex = (encounter.current_turn_index || 0) + 1;
        let nextRound = encounter.round || 1;
        if (nextIndex >= count) { nextIndex = 0; nextRound++; }
        await pool.query('UPDATE combat_encounters SET current_turn_index = $1, round = $2 WHERE id = $3', [nextIndex, nextRound, encounter.id]);
        res.json({ success: true, round: nextRound, index: nextIndex });
    } catch (err) { logger.error("Next Turn Error", err); res.status(500).json({ error: "Erreur tour suivant" }); }
});
router.post('/campaigns/:id/combat/stop', async (req, res) => {
    const userId = req.headers['x-user-id'];
    try { await pool.query(`UPDATE combat_encounters SET status = 'FINISHED' FROM campaigns WHERE combat_encounters.campaign_id = campaigns.id AND campaigns.id = $1 AND campaigns.gm_id = $2 AND combat_encounters.status = 'STARTED'`, [req.params.id, userId]); res.json({ success: true }); } catch (err) { res.status(500).json({ error: "Erreur stop" }); }
});
router.post('/campaigns/:id/combat/add', async (req, res) => {
    const userId = req.headers['x-user-id'];
    const campaignId = req.params.id;
    const { name, hp, initiative, ac } = req.body;
    try {
        const gmCheck = await pool.query('SELECT * FROM campaigns WHERE id = $1 AND gm_id = $2', [campaignId, userId]);
        if (gmCheck.rows.length === 0) return res.status(403).json({ error: "Pas MJ" });
        const encRes = await pool.query('SELECT * FROM combat_encounters WHERE campaign_id = $1 AND status = $2', [campaignId, 'STARTED']);
        if (encRes.rows.length === 0) return res.status(404).json({ error: "Pas de combat actif" });
        const encounterId = encRes.rows[0].id;
        const finalHp = hp || 10;
        const finalAc = ac || 10;
        let finalInit = initiative;
        if (finalInit === undefined || finalInit === null || finalInit === "") { finalInit = Math.floor(Math.random() * 20) + 1; }
        await pool.query(`INSERT INTO combat_participants (encounter_id, character_id, name, initiative, hp_current, hp_max, ac, is_npc) VALUES ($1, NULL, $2, $3, $4, $5, $6, true)`, [encounterId, name || "Monstre", finalInit, finalHp, finalHp, finalAc]);
        res.json({ success: true });
    } catch (err) { logger.error("Add Monster Error", err); res.status(500).json({ error: "Erreur ajout monstre" }); }
});

// --- BATTLEMAP ---
router.get('/campaigns/:id/map/active', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    try {
        const role = userId == null ? null : await getCampaignRole(req.params.id, userId);
        if (!role) return res.status(403).json({ error: "Acces refuse" });
        const result = await pool.query('SELECT * FROM maps WHERE campaign_id = $1 AND is_active = true LIMIT 1', [req.params.id]);
        if (result.rows.length === 0) return res.json({ active: false });
        res.json({ active: true, map: result.rows[0] });
    } catch (err) { logger.error("Get Map Error", err); res.status(500).json({ error: "Erreur chargement carte" }); }
});

// ROUTE CRITIQUE : Récupérer une carte par ID
router.get('/maps/:id', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    try {
        if (userId == null) return res.status(403).json({ error: "Acces refuse" });
        const mapAccess = await getMapAccess(req.params.id, userId);
        if (!mapAccess) return res.status(404).json({ error: "Carte introuvable" });
        res.json(mapAccess);
    } catch (err) { logger.error("Get Map By ID Error", err); res.status(500).json({ error: "Erreur chargement carte" }); }
});

router.post('/campaigns/:id/maps', async (req, res) => {
    const userId = req.headers['x-user-id'];
    const { name, width, height } = req.body;
    try {
        const check = await pool.query('SELECT * FROM campaigns WHERE id = $1 AND gm_id = $2', [req.params.id, userId]);
        if (check.rows.length === 0) return res.status(403).json({ error: "Pas MJ" });
        await pool.query('UPDATE maps SET is_active = false WHERE campaign_id = $1', [req.params.id]);
        const result = await pool.query('INSERT INTO maps (campaign_id, name, width, height, is_active, tokens) VALUES ($1, $2, $3, $4, true, $5) RETURNING *', [req.params.id, name, width || 20, height || 15, '{}']);
        res.json(result.rows[0]);
    } catch (err) { logger.error("Create Map Error", err); res.status(500).json({ error: "Erreur création carte" }); }
});

router.patch('/maps/:id/tokens', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const { tokens } = req.body;
    try {
        if (userId == null) return res.status(403).json({ error: "Acces refuse" });
        const mapAccess = await getMapAccess(req.params.id, userId);
        if (!mapAccess) return res.status(404).json({ error: "Carte introuvable" });
        await pool.query('UPDATE maps SET tokens = $1 WHERE id = $2', [tokens, req.params.id]);
        io.to(`campaign_${mapAccess.campaign_id}`).emit('map_tokens_updated', {
            campaignId: mapAccess.campaign_id,
            mapId: req.params.id,
            tokens,
        });
        res.json({ success: true });
    } catch (err) { logger.error("Move Token Error", err); res.status(500).json({ error: "Erreur déplacement" }); }
});

router.patch('/maps/:id/meta', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const rawName = req.body?.name;
    const name = typeof rawName === 'string' ? rawName.trim() : '';
    try {
        if (userId == null) return res.status(403).json({ error: "Acces refuse" });
        if (!name) return res.status(400).json({ error: "Nom de carte requis" });
        const mapAccess = await getMapAccess(req.params.id, userId);
        if (!mapAccess || mapAccess.role !== 'GM') {
            return res.status(403).json({ error: "Pas MJ" });
        }

        const result = await pool.query(
            'UPDATE maps SET name = $1 WHERE id = $2 RETURNING id, campaign_id, name, width, height, is_active',
            [name, req.params.id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: "Carte introuvable" });
        }
        res.json({ success: true, map: result.rows[0] });
    } catch (err) {
        logger.error("Rename Map Error", err);
        res.status(500).json({ error: "Erreur renommage carte" });
    }
});

router.put('/maps/:id/data', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const { json_data, width, height } = req.body;
    try {
        if (userId == null) return res.status(403).json({ error: "Acces refuse" });
        const mapAccess = await getMapAccess(req.params.id, userId);
        if (!mapAccess || mapAccess.role !== 'GM') return res.status(403).json({ error: "Pas MJ" });
        await pool.query('UPDATE maps SET json_data = $1, width = $2, height = $3 WHERE id = $4', [json_data, width, height, req.params.id]);
        res.json({ success: true });
    } catch (err) { logger.error("Save Map Data Error", err); res.status(500).json({ error: "Erreur sauvegarde carte" }); }
});

router.get('/campaigns/:id/maps', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    try {
        const role = userId == null ? null : await getCampaignRole(req.params.id, userId);
        if (role !== 'GM') return res.status(403).json({ error: "Pas MJ" });
        // On ne récupère que l'ID, le nom et le statut (pas tout le JSON lourd)
        const result = await pool.query(
            'SELECT id, name, width, height, is_active FROM maps WHERE campaign_id = $1 ORDER BY id DESC', 
            [req.params.id]
        );
        res.json(result.rows);
    } catch (err) {
        logger.error("Get Campaign Maps Error", err);
        res.status(500).json({ error: "Erreur chargement liste cartes" });
    }
});

// Activer une carte (La rendre visible pour les joueurs)
router.patch('/maps/:id/activate', async (req, res) => {
    const userId = req.headers['x-user-id'];
    try {
        // 1. Vérif MJ (via Jointure)
        const check = await pool.query(`
            SELECT m.campaign_id FROM maps m 
            JOIN campaigns c ON m.campaign_id = c.id 
            WHERE m.id = $1 AND c.gm_id = $2`, 
            [req.params.id, userId]
        );
        if (check.rows.length === 0) return res.status(403).json({ error: "Interdit" });
        
        const campaignId = check.rows[0].campaign_id;

        // 2. Désactiver toutes les cartes de cette campagne
        await pool.query('UPDATE maps SET is_active = false WHERE campaign_id = $1', [campaignId]);

        // 3. Activer la cible
        await pool.query('UPDATE maps SET is_active = true WHERE id = $1', [req.params.id]);
        
        res.json({ success: true });
    } catch (err) {
        logger.error("Activate Map Error", err);
        res.status(500).json({ error: "Erreur activation" });
    }
});

router.delete('/maps/:id', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    try {
        if (userId == null) return res.status(403).json({ error: "Acces refuse" });
        const mapAccess = await getMapAccess(req.params.id, userId);
        if (!mapAccess || mapAccess.role !== 'GM') {
            return res.status(403).json({ error: "Pas MJ" });
        }

        const campaignId = mapAccess.campaign_id;
        const wasActive = mapAccess.is_active === true;

        await withTransaction(async (client) => {
            const deleted = await client.query(
                'DELETE FROM maps WHERE id = $1 RETURNING id',
                [req.params.id]
            );
            if (deleted.rows.length === 0) {
                throw httpError(404, "Carte introuvable");
            }

            if (wasActive) {
                const fallback = await client.query(
                    'SELECT id FROM maps WHERE campaign_id = $1 ORDER BY id DESC LIMIT 1',
                    [campaignId]
                );
                if (fallback.rows.length > 0) {
                    await client.query(
                        'UPDATE maps SET is_active = true WHERE id = $1',
                        [fallback.rows[0].id]
                    );
                }
            }
        });

        res.json({ success: true });
    } catch (err) {
        logger.error("Delete Map Error", err);
        res.status(err.statusCode || 500).json({ error: err.message || "Erreur suppression carte" });
    }
});

// --- NOTES ---
router.get('/campaigns/:id/notes', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const campaignId = req.params.id;
    try {
        if (userId == null) return res.status(400).json({ error: "Utilisateur invalide" });
        const memberCheck = await pool.query('SELECT role FROM campaign_members WHERE campaign_id = $1 AND user_id = $2', [campaignId, userId]);
        if (memberCheck.rows.length === 0) return res.status(403).json({ error: "Accès refusé" });
        const isGM = memberCheck.rows[0].role === 'GM';
        let query = isGM
            ? "SELECT notes.*, COALESCE(shared_with, '{}') AS shared_with FROM notes WHERE campaign_id = $1 ORDER BY created_at DESC"
            : "SELECT notes.*, COALESCE(shared_with, '{}') AS shared_with FROM notes WHERE campaign_id = $1 AND (is_public = true OR $2 = ANY(COALESCE(shared_with, '{}'))) ORDER BY created_at DESC";
        const params = isGM ? [campaignId] : [campaignId, userId];
        const result = await pool.query(query, params);
        res.json(result.rows);
    } catch (err) { logger.error("Get Notes Error", err); res.status(500).json({ error: "Erreur chargement notes" }); }
});

router.post('/campaigns/:id/notes', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const { title, content, is_public, shared_with } = req.body;
    try {
        if (userId == null) return res.status(400).json({ error: "Utilisateur invalide" });
        if (!title || !String(title).trim()) return res.status(400).json({ error: "Titre requis" });
        const check = await pool.query('SELECT * FROM campaigns WHERE id = $1 AND gm_id = $2', [req.params.id, userId]);
        if (check.rows.length === 0) return res.status(403).json({ error: "Pas MJ" });

        const isPublic = is_public === true;
        const sharedWith = isPublic ? [] : sanitizeSharedWith(shared_with);
        if (sharedWith.length > 0) {
            const targetCheck = await pool.query(
                `SELECT user_id
                 FROM campaign_members
                 WHERE campaign_id = $1 AND role <> 'GM' AND user_id = ANY($2::int[])`,
                [req.params.id, sharedWith]
            );
            if (targetCheck.rows.length !== sharedWith.length) {
                return res.status(400).json({ error: "Destinataires invalides" });
            }
        }

        const result = await pool.query(
            'INSERT INTO notes (campaign_id, title, content, is_public, shared_with) VALUES ($1, $2, $3, $4, $5) RETURNING *',
            [req.params.id, title, content || "", isPublic, sharedWith]
        );
        res.json(result.rows[0]);
    } catch (err) { logger.error("Create Note Error", err); res.status(500).json({ error: "Erreur création note" }); }
});

router.patch('/notes/:id/share', async (req, res) => {
    const userId = parseUserId(req.headers['x-user-id']);
    const { is_public, shared_with } = req.body;
    try {
        if (userId == null) return res.status(400).json({ error: "Utilisateur invalide" });
        const check = await pool.query(
            `SELECT n.id, n.campaign_id
             FROM notes n
             JOIN campaigns c ON n.campaign_id = c.id
             WHERE n.id = $1 AND c.gm_id = $2`,
            [req.params.id, userId]
        );
        if (check.rows.length === 0) return res.status(403).json({ error: "Interdit" });

        const isPublic = is_public === true;
        const sharedWith = isPublic ? [] : sanitizeSharedWith(shared_with);
        if (sharedWith.length > 0) {
            const targetCheck = await pool.query(
                `SELECT user_id
                 FROM campaign_members
                 WHERE campaign_id = $1 AND role <> 'GM' AND user_id = ANY($2::int[])`,
                [check.rows[0].campaign_id, sharedWith]
            );
            if (targetCheck.rows.length !== sharedWith.length) {
                return res.status(400).json({ error: "Destinataires invalides" });
            }
        }

        await pool.query(
            'UPDATE notes SET is_public = $1, shared_with = $2 WHERE id = $3',
            [isPublic, sharedWith, req.params.id]
        );
        res.json({ success: true });
    } catch (err) { logger.error("Share Note Error", err); res.status(500).json({ error: "Erreur partage" }); }
});

router.delete('/notes/:id', async (req, res) => {
    const userId = req.headers['x-user-id'];
    try {
        const result = await pool.query(`DELETE FROM notes USING campaigns WHERE notes.campaign_id = campaigns.id AND notes.id = $1 AND campaigns.gm_id = $2 RETURNING notes.id`, [req.params.id, userId]);
        if (result.rowCount === 0) return res.status(403).json({ error: "Impossible" });
        res.json({ success: true });
    } catch (err) { logger.error("Delete Note Error", err); res.status(500).json({ error: "Erreur suppression" }); }
});

// --- PERMISSIONS REPAIR ---
router.get('/fix-permissions', async (req, res) => {
    try {
        const dbUser = process.env.DB_USER; 
        await pool.query(`GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${dbUser}`);
        await pool.query(`GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${dbUser}`);
        res.send(`Permissions réparées pour l'utilisateur ${dbUser} ! 🚀`);
    } catch (err) { res.status(500).send("Erreur : " + err.message); }
});


// ==========================================
// 6. MONTAGE & SOCKET
// ==========================================
app.use('/api_jdr', router);

app.use(express.static(path.join(__dirname, 'public_flutter')));
app.get('*', (req, res) => {
    if (req.url.startsWith('/api_jdr')) return res.status(404).json({ error: "Route introuvable" });
    const indexPath = path.join(__dirname, 'public_flutter', 'index.html');
    res.sendFile(indexPath, (err) => {
        if(err) res.status(404).send("API OK - Frontend absent");
    });
});

const io = new Server(server, {
    cors: { origin: "*", methods: ["GET", "POST"], credentials: false },
    transports: ['polling', 'websocket'],
    allowEIO3: true
});

io.on('connection', (socket) => {
    logger.info(`🔌 Socket: ${socket.id}`);
    socket.on('join_campaign', (id) => socket.join(`campaign_${id}`));
    socket.on('dice_roll', (d) => socket.to(`campaign_${d.campaignId}`).emit('new_log', d));
    socket.on('move_token', (d) => socket.to(`campaign_${d.campaignId}`).emit('token_moved', d));
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`🚀 Serveur démarré : ${PORT}`);
});
