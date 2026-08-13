/**
 * Mechanic vehicle registry — persists VIN + vehicle metadata per device.
 * Uses PostgreSQL when DATABASE_URL is set; otherwise in-memory.
 */

import { Pool } from 'pg';
import { randomUUID } from 'crypto';

const runningInProduction = process.env.NODE_ENV === 'production';
let pool = null;
let initialized = false;
const memoryStore = new Map();

function normalizeVin(vin) {
  return String(vin || '')
    .trim()
    .toUpperCase()
    .replace(/[^A-HJ-NPR-Z0-9]/g, '');
}

async function ensureInitialized() {
  if (initialized) return;
  initialized = true;
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    if (runningInProduction) {
      console.warn('[vehicle_store] DATABASE_URL not set — using in-memory store');
    }
    return;
  }
  pool = new Pool({ connectionString: databaseUrl });
  await pool.query(`
    CREATE TABLE IF NOT EXISTS mechanic_vehicles (
      id TEXT PRIMARY KEY,
      device_id TEXT NOT NULL,
      client_id TEXT,
      vin TEXT NOT NULL,
      registration_number TEXT,
      make TEXT,
      model TEXT,
      year INTEGER,
      fuel_type TEXT,
      engine_cc REAL,
      cylinders INTEGER,
      engine_type TEXT,
      source TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS mechanic_vehicles_device_idx
    ON mechanic_vehicles (device_id)
  `);
}

export async function saveMechanicVehicle(deviceId, payload) {
  await ensureInitialized();
  const vin = normalizeVin(payload.vin);
  if (vin.length !== 17) {
    throw new Error('A valid 17-character VIN is required');
  }

  const id = payload.id || randomUUID();
  const now = new Date().toISOString();
  const record = {
    id,
    device_id: deviceId,
    client_id: payload.client_id || null,
    vin,
    registration_number: payload.registration_number || null,
    make: payload.make || null,
    model: payload.model || null,
    year: payload.year ?? null,
    fuel_type: payload.fuel_type || null,
    engine_cc: payload.engine_cc ?? null,
    cylinders: payload.cylinders ?? null,
    engine_type: payload.engine_type || null,
    source: payload.source || 'app',
    created_at: payload.created_at || now,
    updated_at: now,
  };

  if (pool) {
    await pool.query(
      `INSERT INTO mechanic_vehicles (
        id, device_id, client_id, vin, registration_number, make, model, year,
        fuel_type, engine_cc, cylinders, engine_type, source, created_at, updated_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
      ON CONFLICT (id) DO UPDATE SET
        client_id = EXCLUDED.client_id,
        vin = EXCLUDED.vin,
        registration_number = EXCLUDED.registration_number,
        make = EXCLUDED.make,
        model = EXCLUDED.model,
        year = EXCLUDED.year,
        fuel_type = EXCLUDED.fuel_type,
        engine_cc = EXCLUDED.engine_cc,
        cylinders = EXCLUDED.cylinders,
        engine_type = EXCLUDED.engine_type,
        source = EXCLUDED.source,
        updated_at = EXCLUDED.updated_at`,
      [
        record.id,
        record.device_id,
        record.client_id,
        record.vin,
        record.registration_number,
        record.make,
        record.model,
        record.year,
        record.fuel_type,
        record.engine_cc,
        record.cylinders,
        record.engine_type,
        record.source,
        record.created_at,
        record.updated_at,
      ],
    );
    return record;
  }

  memoryStore.set(`${deviceId}:${id}`, record);
  return record;
}

export async function listMechanicVehicles(deviceId) {
  await ensureInitialized();
  if (pool) {
    const result = await pool.query(
      `SELECT * FROM mechanic_vehicles WHERE device_id = $1 ORDER BY updated_at DESC`,
      [deviceId],
    );
    return result.rows.map(rowToRecord);
  }
  return [...memoryStore.values()]
    .filter((v) => v.device_id === deviceId)
    .sort((a, b) => String(b.updated_at).localeCompare(String(a.updated_at)));
}

function rowToRecord(row) {
  return {
    id: row.id,
    device_id: row.device_id,
    client_id: row.client_id,
    vin: row.vin,
    registration_number: row.registration_number,
    make: row.make,
    model: row.model,
    year: row.year,
    fuel_type: row.fuel_type,
    engine_cc: row.engine_cc,
    cylinders: row.cylinders,
    engine_type: row.engine_type,
    source: row.source,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

export async function getMechanicVehicleByVin(deviceId, vin) {
  await ensureInitialized();
  const normalized = normalizeVin(vin);
  if (pool) {
    const result = await pool.query(
      `SELECT * FROM mechanic_vehicles WHERE device_id = $1 AND vin = $2 LIMIT 1`,
      [deviceId, normalized],
    );
    return result.rows[0] ? rowToRecord(result.rows[0]) : null;
  }
  return (
    [...memoryStore.values()].find(
      (v) => v.device_id === deviceId && v.vin === normalized,
    ) ?? null
  );
}
