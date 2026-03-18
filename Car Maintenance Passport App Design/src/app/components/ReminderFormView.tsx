import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router';
import { ArrowLeft } from 'lucide-react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { Reminder, Vehicle } from '../types';
import {
  getReminders,
  addReminder,
  updateReminder,
  generateId,
  getVehicles,
  deleteReminder,
} from '../utils/storage';
import { toast } from 'sonner';

export function ReminderFormView() {
  const { id } = useParams();
  const navigate = useNavigate();
  const isEditing = id !== 'new';

  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [formData, setFormData] = useState({
    vehicleId: '',
    title: '',
    dueDate: '',
    dueMileage: '',
    reminderType: 'date' as 'date' | 'mileage' | 'both',
  });

  useEffect(() => {
    const loadedVehicles = getVehicles();
    setVehicles(loadedVehicles);

    if (isEditing && id) {
      const reminders = getReminders();
      const reminder = reminders.find((r) => r.id === id);
      if (reminder) {
        setFormData({
          vehicleId: reminder.vehicleId,
          title: reminder.title,
          dueDate: reminder.dueDate || '',
          dueMileage: reminder.dueMileage?.toString() || '',
          reminderType: reminder.dueDate && reminder.dueMileage
            ? 'both'
            : reminder.dueDate
            ? 'date'
            : 'mileage',
        });
      }
    } else if (loadedVehicles.length > 0) {
      setFormData((prev) => ({ ...prev, vehicleId: loadedVehicles[0].id }));
    }
  }, [id, isEditing]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!formData.vehicleId) {
      toast.error('Please select a vehicle');
      return;
    }

    if (!formData.title) {
      toast.error('Please enter a title');
      return;
    }

    if (!formData.dueDate && !formData.dueMileage) {
      toast.error('Please set either a due date or mileage');
      return;
    }

    const reminderData: Partial<Reminder> = {
      vehicleId: formData.vehicleId,
      title: formData.title,
      dueDate: formData.dueDate || undefined,
      dueMileage: formData.dueMileage ? parseInt(formData.dueMileage) : undefined,
      isCompleted: false,
    };

    if (isEditing && id) {
      updateReminder(id, reminderData);
      toast.success('Reminder updated successfully');
    } else {
      const newReminder: Reminder = {
        ...reminderData,
        id: generateId(),
        isCompleted: false,
        createdAt: new Date().toISOString(),
      } as Reminder;
      addReminder(newReminder);
      toast.success('Reminder added successfully');
    }

    window.dispatchEvent(new Event('storage-update'));
    navigate('/reminders');
  };

  const handleDelete = () => {
    if (id) {
      deleteReminder(id);
      toast.success('Reminder deleted');
      window.dispatchEvent(new Event('storage-update'));
      navigate('/reminders');
    }
  };

  if (vehicles.length === 0) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center px-6">
        <div className="text-center">
          <h2 className="text-xl font-semibold text-white mb-2">No Vehicles</h2>
          <p className="text-slate-400 mb-6">Add a vehicle first to create reminders.</p>
          <Button
            onClick={() => navigate('/vehicle/new')}
            className="bg-orange-500 hover:bg-orange-600 text-white"
          >
            Add Vehicle
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Header */}
      <div className="bg-slate-900 px-6 pt-12 pb-6 sticky top-0 z-10">
        <div className="flex items-center gap-4 mb-4">
          <button
            onClick={() => navigate('/reminders')}
            className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center text-slate-300 hover:bg-slate-700"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <h1 className="text-2xl font-bold text-white">
            {isEditing ? 'Edit Reminder' : 'Add Reminder'}
          </h1>
        </div>
      </div>

      {/* Form */}
      <form onSubmit={handleSubmit} className="px-6 py-6 space-y-6">
        {/* Vehicle Selection */}
        <div className="space-y-2">
          <Label htmlFor="vehicle" className="text-slate-300">
            Vehicle *
          </Label>
          <Select value={formData.vehicleId} onValueChange={(value) => setFormData({ ...formData, vehicleId: value })}>
            <SelectTrigger className="bg-slate-800 border-slate-700 text-white h-12">
              <SelectValue placeholder="Select a vehicle" />
            </SelectTrigger>
            <SelectContent className="bg-slate-800 border-slate-700">
              {vehicles.map((vehicle) => (
                <SelectItem key={vehicle.id} value={vehicle.id} className="text-white">
                  {vehicle.make} {vehicle.model} ({vehicle.year})
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        {/* Title */}
        <div className="space-y-2">
          <Label htmlFor="title" className="text-slate-300">
            Reminder Title *
          </Label>
          <Input
            id="title"
            value={formData.title}
            onChange={(e) => setFormData({ ...formData, title: e.target.value })}
            placeholder="e.g., Oil Change, Inspection"
            className="bg-slate-800 border-slate-700 text-white placeholder:text-slate-500 h-12"
          />
        </div>

        {/* Reminder Type */}
        <div className="space-y-2">
          <Label className="text-slate-300">Reminder Type</Label>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setFormData({ ...formData, reminderType: 'date', dueMileage: '' })}
              className={`flex-1 px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                formData.reminderType === 'date'
                  ? 'bg-orange-500 text-white'
                  : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
              }`}
            >
              Date
            </button>
            <button
              type="button"
              onClick={() => setFormData({ ...formData, reminderType: 'mileage', dueDate: '' })}
              className={`flex-1 px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                formData.reminderType === 'mileage'
                  ? 'bg-orange-500 text-white'
                  : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
              }`}
            >
              Mileage
            </button>
            <button
              type="button"
              onClick={() => setFormData({ ...formData, reminderType: 'both' })}
              className={`flex-1 px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                formData.reminderType === 'both'
                  ? 'bg-orange-500 text-white'
                  : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
              }`}
            >
              Both
            </button>
          </div>
        </div>

        {/* Due Date */}
        {(formData.reminderType === 'date' || formData.reminderType === 'both') && (
          <div className="space-y-2">
            <Label htmlFor="dueDate" className="text-slate-300">
              Due Date
            </Label>
            <Input
              id="dueDate"
              type="date"
              value={formData.dueDate}
              onChange={(e) => setFormData({ ...formData, dueDate: e.target.value })}
              className="bg-slate-800 border-slate-700 text-white h-12"
            />
          </div>
        )}

        {/* Due Mileage */}
        {(formData.reminderType === 'mileage' || formData.reminderType === 'both') && (
          <div className="space-y-2">
            <Label htmlFor="dueMileage" className="text-slate-300">
              Due Mileage (km)
            </Label>
            <Input
              id="dueMileage"
              type="number"
              value={formData.dueMileage}
              onChange={(e) => setFormData({ ...formData, dueMileage: e.target.value })}
              placeholder="e.g., 20000"
              className="bg-slate-800 border-slate-700 text-white placeholder:text-slate-500 h-12"
            />
          </div>
        )}

        {/* Submit Button */}
        <Button
          type="submit"
          className="w-full bg-orange-500 hover:bg-orange-600 text-white h-12 rounded-xl text-base"
        >
          {isEditing ? 'Update Reminder' : 'Add Reminder'}
        </Button>

        {/* Delete Button (only when editing) */}
        {isEditing && (
          <Button
            type="button"
            onClick={handleDelete}
            variant="outline"
            className="w-full border-red-600 text-red-600 hover:bg-red-600 hover:text-white h-12 rounded-xl text-base"
          >
            Delete Reminder
          </Button>
        )}
      </form>
    </div>
  );
}
