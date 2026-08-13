/**
 * Mechanic app API routes — VIN lookup (Attestr + IDSPay + RegCheck), OCR, AI helpers.
 */

import {
  listMechanicVehicles,
  saveMechanicVehicle,
} from './vehicle_store.js';

const IDSPAY_BASE = 'https://api.idspay.in/v3';
const REGCHECK_URL = 'https://www.regcheck.org.uk/api/reg.asmx';
const ATTESTR_RC_URL = 'https://api.attestr.com/api/v2/public/checkx/rc';

function normalizeVehicleRecord(raw, source) {
  const engineType =
    raw.engine_type ||
    buildEngineTypeSummary(raw.fuel_type, raw.engine_cc ?? raw.cubic_capacity, raw.cylinders);
  return {
    registration_number: raw.registration_number || raw.rc_number || raw.registrationNumber || null,
    chassis_number: raw.chassis_number || raw.chassisNumber || raw.vin || null,
    engine_number: raw.engine_number || raw.engineNumber || null,
    make: cleanMakeName(raw.make || raw.CarMake?.CurrentTextValue || raw.MakeDescription || raw.makerDescription) || raw.make || null,
    model: raw.model || raw.CarModel?.CurrentTextValue || raw.ModelDescription || raw.makerModel || null,
    year: Number(raw.year || raw.RegistrationYear || raw.registration_year) || null,
    fuel_type: raw.fuel_type || raw.FuelType?.CurrentTextValue || raw.fuelType || null,
    engine_cc: raw.engine_cc ?? raw.cubic_capacity ?? raw.cubicCapacity ?? null,
    cylinders: raw.cylinders ?? null,
    engine_type: engineType,
    color: raw.color || raw.Color?.CurrentTextValue || raw.colorType || null,
    owner_name: raw.owner_name || raw.ownerName || raw.owner || null,
    registration_date: raw.registration_date || raw.registered || null,
    fitness_expiry: raw.fitness_expiry || null,
    insurance_status: raw.insurance_status || null,
    rc_status: raw.rc_status || null,
    rto: raw.rto || null,
    source,
  };
}

function titleCaseFuel(value) {
  if (!value) return null;
  const lower = String(value).trim().toLowerCase();
  if (!lower) return null;
  return lower[0].toUpperCase() + lower.slice(1);
}

function buildEngineTypeSummary(fuelType, engineCc, cylinders) {
  const parts = [];
  const fuel = titleCaseFuel(fuelType);
  if (fuel) parts.push(fuel);
  const cc = Number(engineCc);
  if (!Number.isNaN(cc) && cc > 0) {
    parts.push(`${cc % 1 === 0 ? cc.toFixed(0) : cc} cc`);
  }
  const cyl = Number(cylinders);
  if (!Number.isNaN(cyl) && cyl > 0) {
    parts.push(`${cyl} cyl`);
  }
  return parts.length ? parts.join(' · ') : null;
}

function cleanMakeName(raw) {
  if (!raw) return null;
  const text = String(raw).trim();
  if (!text) return null;
  const upper = text.toUpperCase();
  const brands = [
    ['MARUTI', 'Maruti Suzuki'],
    ['HYUNDAI', 'Hyundai'],
    ['HONDA', 'Honda'],
    ['TATA', 'Tata'],
    ['MAHINDRA', 'Mahindra'],
    ['TOYOTA', 'Toyota'],
    ['KIA', 'Kia'],
    ['NISSAN', 'Nissan'],
    ['RENAULT', 'Renault'],
    ['SKODA', 'Skoda'],
    ['VOLKSWAGEN', 'Volkswagen'],
    ['FORD', 'Ford'],
    ['BMW', 'BMW'],
    ['MERCEDES', 'Mercedes-Benz'],
    ['AUDI', 'Audi'],
    ['FORCE', 'Force Motors'],
    ['ASHOK LEYLAND', 'Ashok Leyland'],
  ];
  for (const [needle, label] of brands) {
    if (upper.includes(needle)) return label;
  }
  return text.split('(')[0].trim();
}

function parseManufacturedYear(manufactured, registered) {
  if (manufactured) {
    const text = String(manufactured).trim();
    const slashParts = text.split('/');
    if (slashParts.length >= 2) {
      const year = Number(slashParts[slashParts.length - 1]);
      if (year >= 1980 && year <= 2035) return year;
    }
    const year = Number(text);
    if (year >= 1980 && year <= 2035) return year;
  }
  if (registered) {
    const date = new Date(registered);
    if (!Number.isNaN(date.getTime())) return date.getFullYear();
  }
  return null;
}

function summarizeInsurance(data) {
  const provider = data.insuranceProvider?.trim();
  const upto = data.insuranceUpto?.trim();
  if (provider) {
    if (upto && !upto.startsWith('1800')) {
      return `${provider} (until ${upto})`;
    }
    return provider;
  }
  if (upto && !upto.startsWith('1800')) {
    return `Valid until ${upto}`;
  }
  return null;
}

function normalizeAttestrRecord(regNumber, data) {
  const model = data.makerModel?.trim() || data.makerVariant?.trim() || null;
  return normalizeVehicleRecord(
    {
      registration_number: regNumber,
      chassis_number: data.chassisNumber || null,
      engine_number: data.engineNumber || null,
      makerDescription: data.makerDescription || null,
      model,
      year: parseManufacturedYear(data.manufactured, data.registered),
      fuel_type: data.fuelType || null,
      engine_cc: data.cubicCapacity || null,
      cylinders: data.cylinders || null,
      color: data.colorType || null,
      owner_name: data.owner || null,
      registration_date: data.registered || null,
      fitness_expiry: data.fitnessUpto?.startsWith('1800') ? null : data.fitnessUpto,
      insurance_status: summarizeInsurance(data),
      rc_status: data.status || null,
      rto: data.rto || null,
    },
    'attestr',
  );
}

function getAttestrAuthHeader() {
  const token = process.env.ATTESTR_AUTH_TOKEN?.trim();
  if (token) {
    return `Basic ${token}`;
  }
  const clientKey = process.env.ATTESTR_CLIENT_KEY?.trim();
  const clientSecret = process.env.ATTESTR_CLIENT_SECRET?.trim();
  if (clientKey && clientSecret) {
    const encoded = Buffer.from(`${clientKey}:${clientSecret}`).toString('base64');
    return `Basic ${encoded}`;
  }
  return null;
}

async function lookupAttestr(regNumber) {
  const authHeader = getAttestrAuthHeader();
  if (!authHeader) {
    throw new Error('Attestr not configured');
  }
  const res = await fetch(ATTESTR_RC_URL, {
    method: 'POST',
    headers: {
      Authorization: authHeader,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ reg: regNumber.trim().toUpperCase() }),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const message = json.message || json.details || `Attestr HTTP ${res.status}`;
    throw new Error(message);
  }
  if (json.valid === false) {
    throw new Error(json.message || 'Provided vehicle registration number does not exist');
  }
  if (json.valid !== true) {
    throw new Error('Unexpected Attestr response');
  }
  return normalizeAttestrRecord(regNumber, json);
}

async function lookupIdspay(type, value, apiKey) {
  const url =
    type === 'chassis'
      ? `${IDSPAY_BASE}/vehicle/chassis-to-rc`
      : `${IDSPAY_BASE}/vehicle/rc-pro/verify`;
  const body =
    type === 'chassis' ? { chassis_number: value } : { rc_number: value };
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`IDSPay ${res.status}`);
  const json = await res.json();
  return normalizeVehicleRecord(json.data || json, 'idspay');
}

async function lookupRegCheck(value, username) {
  const envelope = `<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <CheckIndia xmlns="http://regcheck.org.uk">
      <RegistrationNumber>${value}</RegistrationNumber>
      <username>${username}</username>
    </CheckIndia>
  </soap:Body>
</soap:Envelope>`;
  const res = await fetch(REGCHECK_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'text/xml; charset=utf-8',
      SOAPAction: 'http://regcheck.org.uk/CheckIndia',
    },
    body: envelope,
  });
  const xml = await res.text();
  const match = xml.match(/<vehicleJson>([\s\S]*?)<\/vehicleJson>/i);
  if (!match) throw new Error('RegCheck parse failed');
  const vehicleJson = JSON.parse(match[1].replace(/&quot;/g, '"'));
  return normalizeVehicleRecord(vehicleJson, 'regcheck');
}

function resolveDeviceId(req) {
  return String(req.headers['x-fixease-device-id'] || '').trim();
}

export function registerMechanicRoutes(app, { aiClient, diagnosisModel, generateContent }) {
  app.post('/api/mechanic/vehicles', async (req, res) => {
    try {
      const deviceId = resolveDeviceId(req);
      if (!deviceId) {
        res.status(400).json({ message: 'x-fixease-device-id header required' });
        return;
      }
      const body = req.body || {};
      const record = await saveMechanicVehicle(deviceId, {
        id: body.id,
        client_id: body.client_id,
        vin: body.vin,
        registration_number: body.registration_number,
        make: body.make,
        model: body.model,
        year: body.year,
        fuel_type: body.fuel_type,
        engine_cc: body.engine_cc,
        cylinders: body.cylinders,
        engine_type: body.engine_type,
        source: body.source || 'mechanic_app',
      });
      res.status(201).json({ vehicle: record });
    } catch (err) {
      res.status(400).json({ message: err.message || 'save failed' });
    }
  });

  app.get('/api/mechanic/vehicles', async (req, res) => {
    try {
      const deviceId = resolveDeviceId(req);
      if (!deviceId) {
        res.status(400).json({ message: 'x-fixease-device-id header required' });
        return;
      }
      const vehicles = await listMechanicVehicles(deviceId);
      res.json({ vehicles });
    } catch (err) {
      res.status(500).json({ message: err.message || 'list failed' });
    }
  });

  app.post('/api/mechanic/vin/lookup', async (req, res) => {
    try {
      const { lookup_type: type = 'registration', value } = req.body || {};
      if (!value || typeof value !== 'string') {
        res.status(400).json({ message: 'value required' });
        return;
      }
      const normalizedValue = value.trim().toUpperCase();
      const attestrAuth = getAttestrAuthHeader();
      const idspayKey = process.env.IDSPAY_API_KEY;
      const regcheckUser = process.env.REGCHECK_USERNAME;
      const hasProviders = Boolean(attestrAuth || idspayKey || regcheckUser);
      let vehicle = null;
      const errors = [];

      if (type === 'registration' && attestrAuth) {
        try {
          vehicle = await lookupAttestr(normalizedValue);
        } catch (e) {
          console.warn('Attestr lookup failed:', e.message);
          errors.push(`Attestr: ${e.message}`);
        }
      } else if (type === 'chassis' && attestrAuth && !idspayKey) {
        res.status(422).json({
          message:
            'Attestr supports registration number only. Enter reg no, or set IDSPAY_API_KEY for chassis/VIN lookup.',
        });
        return;
      }

      if (!vehicle && idspayKey) {
        try {
          vehicle = await lookupIdspay(type, normalizedValue, idspayKey);
        } catch (e) {
          console.warn('IDSPay lookup failed:', e.message);
          errors.push(`IDSPay: ${e.message}`);
        }
      }
      if (!vehicle && regcheckUser && type === 'registration') {
        try {
          vehicle = await lookupRegCheck(normalizedValue, regcheckUser);
        } catch (e) {
          console.warn('RegCheck lookup failed:', e.message);
          errors.push(`RegCheck: ${e.message}`);
        }
      }
      if (!vehicle) {
        if (hasProviders) {
          res.status(422).json({
            message: errors.join(' · ') || 'Vehicle lookup failed',
          });
          return;
        }
        vehicle = normalizeVehicleRecord(
          {
            registration_number: type === 'registration' ? normalizedValue : null,
            chassis_number: type === 'chassis' ? normalizedValue : null,
            make: 'Unknown',
            model: 'Vehicle',
          },
          'fallback',
        );
      }
      res.json({ vehicle });
    } catch (err) {
      res.status(500).json({ message: err.message || 'lookup failed' });
    }
  });

  app.post('/api/mechanic/vin/ocr', async (req, res) => {
    try {
      const { image_base64: imageBase64 } = req.body || {};
      if (!imageBase64) {
        res.status(400).json({ message: 'image_base64 required' });
        return;
      }
      if (!aiClient) {
        res.json({ text: null, message: 'AI not configured' });
        return;
      }
      const text = await generateContent({
        model: diagnosisModel,
        contents: [
          {
            role: 'user',
            parts: [
              {
                text:
                  'Extract ONLY the Indian vehicle registration number or 17-character VIN/chassis from this image. Return plain text, no explanation.',
              },
              {
                inlineData: { mimeType: 'image/jpeg', data: imageBase64 },
              },
            ],
          },
        ],
      });
      res.json({ text: (text || '').trim() });
    } catch (err) {
      res.status(500).json({ message: err.message || 'ocr failed' });
    }
  });

  app.post('/api/mechanic/dvi/summarize', async (req, res) => {
    try {
      const { items = [] } = req.body || {};
      const critical = items.filter((i) => i.status === 'critical').length;
      const monitor = items.filter((i) => i.status === 'monitor').length;
      const good = items.filter((i) => i.status === 'good').length;
      res.json({
        summary: `Inspection: ${good} good, ${monitor} monitor, ${critical} critical of ${items.length} points.`,
      });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });

  app.post('/api/mechanic/estimate/generate', async (req, res) => {
    try {
      const { diagnosis = {} } = req.body || {};
      res.json({
        line_items: [
          {
            description: diagnosis.summary || 'Recommended repair',
            quantity: 1,
            part_cost_inr: 1500,
            labor_hours: 1.5,
            labor_rate_inr: 800,
          },
        ],
      });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });

  app.post('/api/mechanic/diagnose/multi-module', async (req, res) => {
    try {
      const { scan = {} } = req.body || {};
      res.json({
        summary: 'Multi-module scan complete. Review stored and pending codes per module.',
        modules: scan.modules || [],
      });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  });
}
