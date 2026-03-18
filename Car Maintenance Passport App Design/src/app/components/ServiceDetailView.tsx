import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router';
import { ArrowLeft, Edit, Trash2, Calendar, Gauge, DollarSign, FileText } from 'lucide-react';
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
import { ServiceEntry, Vehicle } from '../types';
import { getServiceEntries, getVehicles, deleteServiceEntry } from '../utils/storage';
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

export function ServiceDetailView() {
  const { serviceId } = useParams();
  const navigate = useNavigate();
  const [service, setService] = useState<ServiceEntry | null>(null);
  const [vehicle, setVehicle] = useState<Vehicle | null>(null);

  useEffect(() => {
    if (!serviceId) return;

    const services = getServiceEntries();
    const foundService = services.find((s) => s.id === serviceId);

    if (foundService) {
      setService(foundService);

      const vehicles = getVehicles();
      const foundVehicle = vehicles.find((v) => v.id === foundService.vehicleId);
      setVehicle(foundVehicle || null);
    } else {
      navigate('/timeline');
    }
  }, [serviceId, navigate]);

  const handleDelete = () => {
    if (serviceId && vehicle) {
      deleteServiceEntry(serviceId);
      toast.success('Service deleted');
      window.dispatchEvent(new Event('storage-update'));
      navigate(`/vehicle/${vehicle.id}`);
    }
  };

  if (!service || !vehicle) return null;

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Header */}
      <div className="bg-slate-900 px-6 pt-12 pb-6 sticky top-0 z-10">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-4">
            <button
              onClick={() => navigate(`/vehicle/${vehicle.id}`)}
              className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center text-slate-300 hover:bg-slate-700"
            >
              <ArrowLeft className="w-5 h-5" />
            </button>
            <div>
              <h1 className="text-2xl font-bold text-white">
                {SERVICE_TYPE_LABELS[service.type]}
              </h1>
              <p className="text-sm text-slate-400">
                {vehicle.make} {vehicle.model}
              </p>
            </div>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => navigate(`/vehicle/${vehicle.id}/service/${service.id}/edit`)}
              className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center text-white hover:bg-slate-700"
            >
              <Edit className="w-4 h-4" />
            </button>
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <button className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center text-white hover:bg-slate-700">
                  <Trash2 className="w-4 h-4" />
                </button>
              </AlertDialogTrigger>
              <AlertDialogContent className="bg-slate-900 border-slate-800">
                <AlertDialogHeader>
                  <AlertDialogTitle className="text-white">Delete Service?</AlertDialogTitle>
                  <AlertDialogDescription className="text-slate-400">
                    This will permanently delete this service record. This action cannot be undone.
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
      </div>

      {/* Content */}
      <div className="px-6 py-6 space-y-4">
        {/* Main Info Card */}
        <Card className="bg-slate-900 border-slate-800 p-6 space-y-4">
          {/* Date */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center">
              <Calendar className="w-5 h-5 text-orange-500" />
            </div>
            <div>
              <p className="text-xs text-slate-400">Date</p>
              <p className="text-white font-medium">
                {format(new Date(service.date), 'MMMM d, yyyy')}
              </p>
            </div>
          </div>

          {/* Mileage */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center">
              <Gauge className="w-5 h-5 text-orange-500" />
            </div>
            <div>
              <p className="text-xs text-slate-400">Mileage</p>
              <p className="text-white font-medium">{service.mileage.toLocaleString()} km</p>
            </div>
          </div>

          {/* Cost */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center">
              <DollarSign className="w-5 h-5 text-orange-500" />
            </div>
            <div>
              <p className="text-xs text-slate-400">Cost</p>
              <p className="text-white font-medium text-xl">
                ${service.cost.toFixed(2)} {service.currency}
              </p>
            </div>
          </div>
        </Card>

        {/* Notes */}
        {service.notes && (
          <Card className="bg-slate-900 border-slate-800 p-6">
            <div className="flex items-start gap-3">
              <FileText className="w-5 h-5 text-orange-500 mt-0.5" />
              <div className="flex-1">
                <p className="text-xs text-slate-400 mb-2">Notes</p>
                <p className="text-white leading-relaxed">{service.notes}</p>
              </div>
            </div>
          </Card>
        )}

        {/* Attachments */}
        {service.attachments && service.attachments.length > 0 && (
          <Card className="bg-slate-900 border-slate-800 p-6">
            <h3 className="text-sm text-slate-400 mb-3">Attachments</h3>
            <div className="grid grid-cols-3 gap-3">
              {service.attachments.map((attachment, index) => (
                <div
                  key={index}
                  className="aspect-square rounded-lg bg-slate-800 flex items-center justify-center"
                >
                  <FileText className="w-8 h-8 text-slate-600" />
                </div>
              ))}
            </div>
          </Card>
        )}
      </div>
    </div>
  );
}
