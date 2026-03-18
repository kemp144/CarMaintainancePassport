import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { Calendar, Gauge, Car, FileText } from 'lucide-react';
import { Card } from './ui/card';
import { ServiceEntry, Vehicle } from '../types';
import { getServiceEntries, getVehicles } from '../utils/storage';
import { format } from 'date-fns';

const SERVICE_TYPE_LABELS: Record<string, string> = {
  'oil-change': 'Oil Change',
  'brake-replacement': 'Brake Replacement',
  'tire-rotation': 'Tire Rotation',
  'tire-replacement': 'Tire Replacement',
  battery: 'Battery',
  inspection: 'Inspection',
  transmission: 'Transmission',
  coolant: 'Coolant',
  'air-filter': 'Air Filter',
  'spark-plugs': 'Spark Plugs',
  other: 'Other',
};

export function TimelineView() {
  const [services, setServices] = useState<ServiceEntry[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const navigate = useNavigate();

  useEffect(() => {
    loadData();
  }, []);

  const loadData = () => {
    const allServices = getServiceEntries().sort(
      (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()
    );
    setServices(allServices);
    setVehicles(getVehicles());
  };

  useEffect(() => {
    const handleStorageChange = () => {
      loadData();
    };

    window.addEventListener('storage-update', handleStorageChange);
    return () => window.removeEventListener('storage-update', handleStorageChange);
  }, []);

  const getVehicleForService = (vehicleId: string): Vehicle | undefined => {
    return vehicles.find((v) => v.id === vehicleId);
  };

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Header */}
      <div className="bg-gradient-to-b from-slate-900 to-slate-950 px-6 pt-12 pb-8">
        <h1 className="text-3xl font-bold text-white mb-2">Timeline</h1>
        <p className="text-slate-400">
          {services.length === 0
            ? 'No service records yet'
            : `${services.length} service ${services.length === 1 ? 'record' : 'records'}`}
        </p>
      </div>

      {/* Content */}
      <div className="px-6 pt-4 pb-6">
        {services.length === 0 ? (
          /* Empty State */
          <div className="flex flex-col items-center justify-center py-16 px-6">
            <div className="w-24 h-24 rounded-full bg-slate-800/50 flex items-center justify-center mb-6">
              <FileText className="w-12 h-12 text-slate-600" />
            </div>
            <h2 className="text-xl font-semibold text-white mb-2">No Services Yet</h2>
            <p className="text-slate-400 text-center mb-8 max-w-xs">
              Add a vehicle and log your first service to see your maintenance timeline.
            </p>
          </div>
        ) : (
          /* Timeline List */
          <div className="space-y-3">
            {services.map((service) => {
              const vehicle = getVehicleForService(service.vehicleId);
              if (!vehicle) return null;

              return (
                <Card
                  key={service.id}
                  onClick={() => navigate(`/service/${service.id}`)}
                  className="bg-slate-900 border-slate-800 p-4 cursor-pointer hover:bg-slate-800/80 transition-colors"
                >
                  {/* Vehicle Badge */}
                  <div className="flex items-center gap-2 mb-3">
                    <div className="w-6 h-6 rounded-full bg-slate-800 flex items-center justify-center">
                      <Car className="w-3.5 h-3.5 text-orange-500" />
                    </div>
                    <span className="text-xs text-slate-400">
                      {vehicle.make} {vehicle.model}
                    </span>
                  </div>

                  {/* Service Info */}
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <h3 className="font-semibold text-white mb-1">
                        {SERVICE_TYPE_LABELS[service.type]}
                      </h3>
                      <div className="flex items-center gap-2 text-sm text-slate-400">
                        <Calendar className="w-3.5 h-3.5" />
                        {format(new Date(service.date), 'MMM d, yyyy')}
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="font-semibold text-white">${service.cost}</p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 text-sm text-slate-400">
                    <Gauge className="w-3.5 h-3.5" />
                    {service.mileage.toLocaleString()} km
                  </div>

                  {service.notes && (
                    <p className="text-sm text-slate-500 mt-2 line-clamp-1">{service.notes}</p>
                  )}
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
