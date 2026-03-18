import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router';
import { ArrowLeft, Camera, X } from 'lucide-react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Textarea } from './ui/textarea';
import { ServiceEntry, ServiceType, Vehicle } from '../types';
import {
  getServiceEntries,
  addServiceEntry,
  updateServiceEntry,
  generateId,
  getVehicles,
} from '../utils/storage';
import { toast } from 'sonner';

const SERVICE_TYPES: { value: ServiceType; label: string }[] = [
  { value: 'oil-change', label: 'Oil Change' },
  { value: 'brake-replacement', label: 'Brake Replacement' },
  { value: 'tire-rotation', label: 'Tire Rotation' },
  { value: 'tire-replacement', label: 'Tire Replacement' },
  { value: 'battery', label: 'Battery' },
  { value: 'inspection', label: 'Inspection' },
  { value: 'transmission', label: 'Transmission' },
  { value: 'coolant', label: 'Coolant' },
  { value: 'air-filter', label: 'Air Filter' },
  { value: 'spark-plugs', label: 'Spark Plugs' },
  { value: 'other', label: 'Other' },
];

export function ServiceEntryFormView() {
  const { vehicleId, serviceId } = useParams();
  const navigate = useNavigate();
  const isEditing = serviceId !== 'new';

  const [vehicle, setVehicle] = useState<Vehicle | null>(null);
  const [formData, setFormData] = useState({
    date: new Date().toISOString().split('T')[0],
    mileage: 0,
    type: 'oil-change' as ServiceType,
    cost: 0,
    notes: '',
    attachments: [] as string[],
  });

  useEffect(() => {
    // Load vehicle
    if (vehicleId) {
      const vehicles = getVehicles();
      const foundVehicle = vehicles.find((v) => v.id === vehicleId);
      if (foundVehicle) {
        setVehicle(foundVehicle);
      } else {
        navigate('/');
        return;
      }
    }

    // Load service entry if editing
    if (isEditing && serviceId) {
      const services = getServiceEntries();
      const service = services.find((s) => s.id === serviceId);
      if (service) {
        setFormData({
          date: service.date,
          mileage: service.mileage,
          type: service.type,
          cost: service.cost,
          notes: service.notes || '',
          attachments: service.attachments || [],
        });
      }
    }
  }, [vehicleId, serviceId, isEditing, navigate]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!vehicleId) return;

    if (formData.mileage <= 0) {
      toast.error('Please enter a valid mileage');
      return;
    }

    if (isEditing && serviceId) {
      updateServiceEntry(serviceId, formData);
      toast.success('Service updated successfully');
    } else {
      const newService: ServiceEntry = {
        ...formData,
        id: generateId(),
        vehicleId,
        currency: 'USD',
        createdAt: new Date().toISOString(),
      };
      addServiceEntry(newService);
      toast.success('Service added successfully');
    }

    window.dispatchEvent(new Event('storage-update'));
    navigate(`/vehicle/${vehicleId}`);
  };

  const handleAddAttachment = () => {
    // Simulate adding attachment
    toast.success('Attachment added (demo)');
    setFormData({
      ...formData,
      attachments: [...formData.attachments, `attachment-${Date.now()}`],
    });
  };

  const handleRemoveAttachment = (index: number) => {
    const newAttachments = formData.attachments.filter((_, i) => i !== index);
    setFormData({ ...formData, attachments: newAttachments });
  };

  if (!vehicle) return null;

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Header */}
      <div className="bg-slate-900 px-6 pt-12 pb-6 sticky top-0 z-10">
        <div className="flex items-center gap-4 mb-2">
          <button
            onClick={() => navigate(`/vehicle/${vehicleId}`)}
            className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center text-slate-300 hover:bg-slate-700"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <h1 className="text-2xl font-bold text-white">
              {isEditing ? 'Edit Service' : 'Add Service'}
            </h1>
            <p className="text-sm text-slate-400">
              {vehicle.make} {vehicle.model}
            </p>
          </div>
        </div>
      </div>

      {/* Form */}
      <form onSubmit={handleSubmit} className="px-6 py-6 space-y-6">
        {/* Service Type */}
        <div className="space-y-2">
          <Label className="text-slate-300">Service Type</Label>
          <div className="flex flex-wrap gap-2">
            {SERVICE_TYPES.map((type) => (
              <button
                key={type.value}
                type="button"
                onClick={() => setFormData({ ...formData, type: type.value })}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  formData.type === type.value
                    ? 'bg-orange-500 text-white'
                    : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                }`}
              >
                {type.label}
              </button>
            ))}
          </div>
        </div>

        {/* Date */}
        <div className="space-y-2">
          <Label htmlFor="date" className="text-slate-300">
            Date
          </Label>
          <Input
            id="date"
            type="date"
            value={formData.date}
            onChange={(e) => setFormData({ ...formData, date: e.target.value })}
            className="bg-slate-800 border-slate-700 text-white h-12"
          />
        </div>

        {/* Mileage */}
        <div className="space-y-2">
          <Label htmlFor="mileage" className="text-slate-300">
            Mileage (km)
          </Label>
          <Input
            id="mileage"
            type="number"
            value={formData.mileage || ''}
            onChange={(e) => setFormData({ ...formData, mileage: parseInt(e.target.value) || 0 })}
            placeholder="e.g., 15000"
            className="bg-slate-800 border-slate-700 text-white placeholder:text-slate-500 h-12"
          />
        </div>

        {/* Cost */}
        <div className="space-y-2">
          <Label htmlFor="cost" className="text-slate-300">
            Cost ($)
          </Label>
          <Input
            id="cost"
            type="number"
            step="0.01"
            value={formData.cost || ''}
            onChange={(e) => setFormData({ ...formData, cost: parseFloat(e.target.value) || 0 })}
            placeholder="0.00"
            className="bg-slate-800 border-slate-700 text-white placeholder:text-slate-500 h-12"
          />
        </div>

        {/* Notes */}
        <div className="space-y-2">
          <Label htmlFor="notes" className="text-slate-300">
            Notes (Optional)
          </Label>
          <Textarea
            id="notes"
            value={formData.notes}
            onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
            placeholder="Add any additional details about this service..."
            className="bg-slate-800 border-slate-700 text-white placeholder:text-slate-500 min-h-24"
          />
        </div>

        {/* Attachments */}
        <div className="space-y-2">
          <Label className="text-slate-300">Attachments (Optional)</Label>
          <button
            type="button"
            onClick={handleAddAttachment}
            className="w-full h-24 rounded-lg bg-slate-800 border-2 border-dashed border-slate-700 hover:border-orange-500 transition-colors flex flex-col items-center justify-center gap-2 text-slate-400 hover:text-orange-500"
          >
            <Camera className="w-6 h-6" />
            <span className="text-sm">Add Receipt or Photo</span>
          </button>

          {formData.attachments.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-3">
              {formData.attachments.map((attachment, index) => (
                <div
                  key={index}
                  className="relative w-20 h-20 rounded-lg bg-slate-800 flex items-center justify-center"
                >
                  <Camera className="w-6 h-6 text-slate-600" />
                  <button
                    type="button"
                    onClick={() => handleRemoveAttachment(index)}
                    className="absolute -top-2 -right-2 w-6 h-6 rounded-full bg-red-600 flex items-center justify-center text-white"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Submit Button */}
        <Button
          type="submit"
          className="w-full bg-orange-500 hover:bg-orange-600 text-white h-12 rounded-xl text-base"
        >
          {isEditing ? 'Update Service' : 'Add Service'}
        </Button>
      </form>
    </div>
  );
}
