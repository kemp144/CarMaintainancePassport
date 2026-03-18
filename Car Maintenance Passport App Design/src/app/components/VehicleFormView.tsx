import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router';
import { ArrowLeft, Camera, X } from 'lucide-react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Vehicle } from '../types';
import { getVehicles, addVehicle, updateVehicle, generateId } from '../utils/storage';
import { toast } from 'sonner';

export function VehicleFormView() {
  const { id } = useParams();
  const navigate = useNavigate();
  const isEditing = id !== 'new';

  const [formData, setFormData] = useState({
    make: '',
    model: '',
    year: new Date().getFullYear(),
    vin: '',
    licensePlate: '',
    imageUrl: '',
  });

  useEffect(() => {
    if (isEditing && id) {
      const vehicles = getVehicles();
      const vehicle = vehicles.find((v) => v.id === id);
      if (vehicle) {
        setFormData({
          make: vehicle.make,
          model: vehicle.model,
          year: vehicle.year,
          vin: vehicle.vin || '',
          licensePlate: vehicle.licensePlate || '',
          imageUrl: vehicle.imageUrl || '',
        });
      }
    }
  }, [id, isEditing]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!formData.make || !formData.model) {
      toast.error('Please fill in make and model');
      return;
    }

    if (isEditing && id) {
      updateVehicle(id, formData);
      toast.success('Vehicle updated successfully');
    } else {
      const newVehicle: Vehicle = {
        ...formData,
        id: generateId(),
        createdAt: new Date().toISOString(),
      };
      addVehicle(newVehicle);
      toast.success('Vehicle added successfully');
    }

    // Trigger storage update event
    window.dispatchEvent(new Event('storage-update'));
    navigate('/');
  };

  const handleImageUpload = () => {
    // Simulate image upload - in a real app, this would open camera/photo library
    const sampleImages = [
      'https://images.unsplash.com/photo-1661333587737-9b7dac4b29d4?w=400',
      'https://images.unsplash.com/photo-1772456595795-e0ee5f1eddf0?w=400',
      'https://images.unsplash.com/photo-1760688192126-ceda9e1dd0c2?w=400',
    ];
    const randomImage = sampleImages[Math.floor(Math.random() * sampleImages.length)];
    setFormData({ ...formData, imageUrl: randomImage });
    toast.success('Image added');
  };

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Header */}
      <div className="bg-slate-900 px-6 pt-12 pb-6 sticky top-0 z-10">
        <div className="flex items-center gap-4 mb-4">
          <button
            onClick={() => navigate('/')}
            className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center text-slate-300 hover:bg-slate-700"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <h1 className="text-2xl font-bold text-white">
            {isEditing ? 'Edit Vehicle' : 'Add Vehicle'}
          </h1>
        </div>
      </div>

      {/* Form */}
      <form onSubmit={handleSubmit} className="px-6 py-6 space-y-6">
        {/* Image Upload */}
        <div className="space-y-2">
          <Label className="text-slate-300">Vehicle Photo</Label>
          {formData.imageUrl ? (
            <div className="relative w-full h-48 rounded-xl bg-slate-800 overflow-hidden">
              <img
                src={formData.imageUrl}
                alt="Vehicle"
                className="w-full h-full object-cover"
              />
              <button
                type="button"
                onClick={() => setFormData({ ...formData, imageUrl: '' })}
                className="absolute top-3 right-3 w-8 h-8 rounded-full bg-slate-900/80 flex items-center justify-center text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
          ) : (
            <button
              type="button"
              onClick={handleImageUpload}
              className="w-full h-48 rounded-xl bg-slate-800 border-2 border-dashed border-slate-700 hover:border-orange-500 transition-colors flex flex-col items-center justify-center gap-2 text-slate-400 hover:text-orange-500"
            >
              <Camera className="w-8 h-8" />
              <span className="text-sm">Add Photo</span>
            </button>
          )}
        </div>

        {/* Make */}
        <div className="space-y-2">
          <Label htmlFor="make" className="text-slate-300">
            Make *
          </Label>
          <Input
            id="make"
            value={formData.make}
            onChange={(e) => setFormData({ ...formData, make: e.target.value })}
            placeholder="e.g., Toyota, BMW, Honda"
            className="bg-slate-800 border-slate-700 text-white placeholder:text-slate-500 h-12"
          />
        </div>

        {/* Model */}
        <div className="space-y-2">
          <Label htmlFor="model" className="text-slate-300">
            Model *
          </Label>
          <Input
            id="model"
            value={formData.model}
            onChange={(e) => setFormData({ ...formData, model: e.target.value })}
            placeholder="e.g., Camry, 3 Series, Civic"
            className="bg-slate-800 border-slate-700 text-white placeholder:text-slate-500 h-12"
          />
        </div>

        {/* Year */}
        <div className="space-y-2">
          <Label htmlFor="year" className="text-slate-300">
            Year
          </Label>
          <Input
            id="year"
            type="number"
            value={formData.year}
            onChange={(e) => setFormData({ ...formData, year: parseInt(e.target.value) })}
            placeholder="2024"
            className="bg-slate-800 border-slate-700 text-white placeholder:text-slate-500 h-12"
          />
        </div>

        {/* VIN */}
        <div className="space-y-2">
          <Label htmlFor="vin" className="text-slate-300">
            VIN (Optional)
          </Label>
          <Input
            id="vin"
            value={formData.vin}
            onChange={(e) => setFormData({ ...formData, vin: e.target.value })}
            placeholder="Vehicle Identification Number"
            className="bg-slate-800 border-slate-700 text-white placeholder:text-slate-500 h-12 font-mono"
          />
        </div>

        {/* License Plate */}
        <div className="space-y-2">
          <Label htmlFor="licensePlate" className="text-slate-300">
            License Plate (Optional)
          </Label>
          <Input
            id="licensePlate"
            value={formData.licensePlate}
            onChange={(e) => setFormData({ ...formData, licensePlate: e.target.value })}
            placeholder="ABC-1234"
            className="bg-slate-800 border-slate-700 text-white placeholder:text-slate-500 h-12 font-mono"
          />
        </div>

        {/* Submit Button */}
        <Button
          type="submit"
          className="w-full bg-orange-500 hover:bg-orange-600 text-white h-12 rounded-xl text-base"
        >
          {isEditing ? 'Update Vehicle' : 'Add Vehicle'}
        </Button>
      </form>
    </div>
  );
}
