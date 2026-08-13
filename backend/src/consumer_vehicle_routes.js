/**
 * Consumer app vehicle registry — persists VIN + garage vehicle metadata per device.
 */

import {
  listMechanicVehicles,
  saveMechanicVehicle,
} from './vehicle_store.js';

function resolveDeviceId(req) {
  return String(req.headers['x-fixease-device-id'] || '').trim();
}

export function registerConsumerVehicleRoutes(app) {
  app.post('/api/vehicles', async (req, res) => {
    try {
      const deviceId = resolveDeviceId(req);
      if (!deviceId) {
        res.status(400).json({ message: 'x-fixease-device-id header required' });
        return;
      }
      const body = req.body || {};
      const record = await saveMechanicVehicle(deviceId, {
        id: body.id,
        vin: body.vin,
        make: body.make,
        model: body.model,
        year: body.year,
        fuel_type: body.fuel_type,
        engine_type: body.variant,
        source: body.source || 'consumer_app',
      });
      res.status(201).json({ vehicle: record });
    } catch (err) {
      res.status(400).json({ message: err.message || 'save failed' });
    }
  });

  app.get('/api/vehicles', async (req, res) => {
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
}
