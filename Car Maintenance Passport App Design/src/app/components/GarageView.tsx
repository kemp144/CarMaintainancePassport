import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { Plus, Car as CarIcon } from 'lucide-react';
import { Button } from './ui/button';
import { Card } from './ui/card';
import { Vehicle } from '../types';
import { getVehicles } from '../utils/storage';

export function GarageView() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const navigate = useNavigate();

  useEffect(() => {
    loadVehicles();
  }, []);

  const loadVehicles = () => {
    const loadedVehicles = getVehicles();
    setVehicles(loadedVehicles);
  };

  // Listen for storage changes (when a vehicle is added/updated)
  useEffect(() => {
    const handleStorageChange = () => {
      loadVehicles();
    };

    window.addEventListener('storage-update', handleStorageChange);
    return () => window.removeEventListener('storage-update', handleStorageChange);
  }, []);

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Header */}
      <div className="bg-gradient-to-b from-slate-900 to-slate-950 px-6 pt-12 pb-8">
        <h1 className="text-3xl font-bold text-white mb-2">My Garage</h1>
        <p className="text-slate-400">
          {vehicles.length === 0
            ? 'Add your first vehicle to get started'
            : `${vehicles.length} ${vehicles.length === 1 ? 'vehicle' : 'vehicles'}`}
        </p>
      </div>

      {/* Content */}
      <div className="px-6 pt-4">
        {vehicles.length === 0 ? (
          /* Empty State */
          <div className="flex flex-col items-center justify-center py-16 px-6">
            <div className="w-24 h-24 rounded-full bg-slate-800/50 flex items-center justify-center mb-6">
              <CarIcon className="w-12 h-12 text-slate-600" />
            </div>
            <h2 className="text-xl font-semibold text-white mb-2">No Vehicles Yet</h2>
            <p className="text-slate-400 text-center mb-8 max-w-xs">
              Start building your digital service logbook by adding your first vehicle.
            </p>
            <Button
              onClick={() => navigate('/vehicle/new')}
              className="bg-orange-500 hover:bg-orange-600 text-white rounded-xl h-12 px-8"
            >
              <Plus className="mr-2 w-5 h-5" />
              Add Vehicle
            </Button>
          </div>
        ) : (
          /* Vehicle Cards */
          <div className="space-y-4 pb-6">
            {vehicles.map((vehicle) => (
              <Card
                key={vehicle.id}
                onClick={() => navigate(`/vehicle/${vehicle.id}`)}
                className="bg-slate-900 border-slate-800 overflow-hidden cursor-pointer hover:bg-slate-800/80 transition-colors"
              >
                <div className="flex gap-4 p-4">
                  {/* Vehicle Image */}
                  <div className="w-24 h-24 rounded-lg bg-slate-800 overflow-hidden flex-shrink-0">
                    {vehicle.imageUrl ? (
                      <img
                        src={vehicle.imageUrl}
                        alt={`${vehicle.make} ${vehicle.model}`}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center">
                        <CarIcon className="w-10 h-10 text-slate-600" />
                      </div>
                    )}
                  </div>

                  {/* Vehicle Info */}
                  <div className="flex-1 min-w-0">
                    <h3 className="text-lg font-semibold text-white mb-1 truncate">
                      {vehicle.make} {vehicle.model}
                    </h3>
                    <p className="text-sm text-slate-400 mb-2">{vehicle.year}</p>
                    {vehicle.licensePlate && (
                      <div className="inline-block px-3 py-1 bg-slate-800 rounded-md">
                        <span className="text-xs font-mono text-slate-300">
                          {vehicle.licensePlate}
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>

      {/* Floating Add Button */}
      {vehicles.length > 0 && (
        <button
          onClick={() => navigate('/vehicle/new')}
          className="fixed bottom-24 right-6 w-14 h-14 bg-orange-500 hover:bg-orange-600 text-white rounded-full shadow-lg flex items-center justify-center transition-colors"
        >
          <Plus className="w-6 h-6" />
        </button>
      )}
    </div>
  );
}
