import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router';
import {
  ArrowLeft,
  Plus,
  Edit,
  Trash2,
  Calendar,
  Gauge,
  DollarSign,
  FileText,
} from 'lucide-react';
import { Button } from './ui/button';
import { Card } from './ui/card';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from './ui/alert-dialog';
import { Vehicle, ServiceEntry } from '../types';
import { getVehicles, getServiceEntriesForVehicle, deleteVehicle } from '../utils/storage';
import { toast } from 'sonner';
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

export function VehicleDetailView() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [vehicle, setVehicle] = useState<Vehicle | null>(null);
  const [services, setServices] = useState<ServiceEntry[]>([]);

  useEffect(() => {
    loadVehicleData();
  }, [id]);

  const loadVehicleData = () => {
    if (!id) return;

    const vehicles = getVehicles();
    const foundVehicle = vehicles.find((v) => v.id === id);
    if (foundVehicle) {
      setVehicle(foundVehicle);
      const vehicleServices = getServiceEntriesForVehicle(id);
      setServices(vehicleServices);
    } else {
      navigate('/');
    }
  };

  useEffect(() => {
    const handleStorageChange = () => {
      loadVehicleData();
    };

    window.addEventListener('storage-update', handleStorageChange);
    return () => window.removeEventListener('storage-update', handleStorageChange);
  }, [id]);

  const handleDelete = () => {
    if (id) {
      deleteVehicle(id);
      toast.success('Vehicle deleted');
      window.dispatchEvent(new Event('storage-update'));
      navigate('/');
    }
  };

  if (!vehicle) return null;

  const totalCost = services.reduce((sum, service) => sum + service.cost, 0);

  return (
    <div className="min-h-screen bg-slate-950 pb-6">
      {/* Header with Image */}
      <div className="relative">
        {/* Vehicle Image */}
        <div className="h-56 bg-slate-900 overflow-hidden">
          {vehicle.imageUrl ? (
            <img
              src={vehicle.imageUrl}
              alt={`${vehicle.make} ${vehicle.model}`}
              className="w-full h-full object-cover"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center bg-gradient-to-b from-slate-800 to-slate-900">
              <div className="text-slate-600 text-center">
                <Calendar className="w-16 h-16 mx-auto mb-2" />
                <p className="text-sm">No photo</p>
              </div>
            </div>
          )}
        </div>

        {/* Back Button */}
        <button
          onClick={() => navigate('/')}
          className="absolute top-12 left-6 w-10 h-10 rounded-full bg-slate-900/80 backdrop-blur flex items-center justify-center text-white"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>

        {/* Actions */}
        <div className="absolute top-12 right-6 flex gap-2">
          <button
            onClick={() => navigate(`/vehicle/${id}/edit`)}
            className="w-10 h-10 rounded-full bg-slate-900/80 backdrop-blur flex items-center justify-center text-white"
          >
            <Edit className="w-4 h-4" />
          </button>
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <button className="w-10 h-10 rounded-full bg-slate-900/80 backdrop-blur flex items-center justify-center text-white">
                <Trash2 className="w-4 h-4" />
              </button>
            </AlertDialogTrigger>
            <AlertDialogContent className="bg-slate-900 border-slate-800">
              <AlertDialogHeader>
                <AlertDialogTitle className="text-white">Delete Vehicle?</AlertDialogTitle>
                <AlertDialogDescription className="text-slate-400">
                  This will permanently delete this vehicle and all its service records and
                  reminders. This action cannot be undone.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel className="bg-slate-800 text-white border-slate-700">
                  Cancel
                </AlertDialogCancel>
                <AlertDialogAction
                  onClick={handleDelete}
                  className="bg-red-600 hover:bg-red-700 text-white"
                >
                  Delete
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </div>
      </div>

      {/* Vehicle Info */}
      <div className="px-6 -mt-6 mb-6">
        <Card className="bg-slate-900 border-slate-800 p-6">
          <h1 className="text-2xl font-bold text-white mb-2">
            {vehicle.make} {vehicle.model}
          </h1>
          <p className="text-slate-400 mb-4">{vehicle.year}</p>
          <div className="flex flex-wrap gap-3">
            {vehicle.licensePlate && (
              <div className="px-3 py-1.5 bg-slate-800 rounded-lg">
                <span className="text-xs font-mono text-slate-300">{vehicle.licensePlate}</span>
              </div>
            )}
            {vehicle.vin && (
              <div className="px-3 py-1.5 bg-slate-800 rounded-lg">
                <span className="text-xs font-mono text-slate-300">VIN: {vehicle.vin}</span>
              </div>
            )}
          </div>
        </Card>
      </div>

      {/* Stats */}
      <div className="px-6 mb-6">
        <div className="grid grid-cols-2 gap-3">
          <Card className="bg-slate-900 border-slate-800 p-4">
            <div className="flex items-center gap-2 mb-2">
              <FileText className="w-4 h-4 text-orange-500" />
              <span className="text-xs text-slate-400">Services</span>
            </div>
            <p className="text-2xl font-bold text-white">{services.length}</p>
          </Card>
          <Card className="bg-slate-900 border-slate-800 p-4">
            <div className="flex items-center gap-2 mb-2">
              <DollarSign className="w-4 h-4 text-orange-500" />
              <span className="text-xs text-slate-400">Total Cost</span>
            </div>
            <p className="text-2xl font-bold text-white">${totalCost.toFixed(0)}</p>
          </Card>
        </div>
      </div>

      {/* Service History */}
      <div className="px-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-white">Service History</h2>
          <Button
            onClick={() => navigate(`/vehicle/${id}/service/new`)}
            size="sm"
            className="bg-orange-500 hover:bg-orange-600 text-white rounded-lg"
          >
            <Plus className="w-4 h-4 mr-1" />
            Add Service
          </Button>
        </div>

        {services.length === 0 ? (
          <Card className="bg-slate-900 border-slate-800 p-8 text-center">
            <FileText className="w-12 h-12 text-slate-600 mx-auto mb-3" />
            <p className="text-slate-400 mb-4">No service records yet</p>
            <Button
              onClick={() => navigate(`/vehicle/${id}/service/new`)}
              size="sm"
              className="bg-slate-800 hover:bg-slate-700 text-white"
            >
              Add First Service
            </Button>
          </Card>
        ) : (
          <div className="space-y-3">
            {services.map((service) => (
              <Card
                key={service.id}
                onClick={() => navigate(`/service/${service.id}`)}
                className="bg-slate-900 border-slate-800 p-4 cursor-pointer hover:bg-slate-800/80 transition-colors"
              >
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
            ))}
          </div>
        )}
      </div>
    </div>
  );
}