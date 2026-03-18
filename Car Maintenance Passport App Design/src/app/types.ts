export interface Vehicle {
  id: string;
  make: string;
  model: string;
  year: number;
  vin?: string;
  licensePlate?: string;
  imageUrl?: string;
  createdAt: string;
}

export interface ServiceEntry {
  id: string;
  vehicleId: string;
  date: string;
  mileage: number;
  type: ServiceType;
  cost: number;
  currency: string;
  notes?: string;
  attachments?: string[];
  createdAt: string;
}

export type ServiceType =
  | 'oil-change'
  | 'brake-replacement'
  | 'tire-rotation'
  | 'tire-replacement'
  | 'battery'
  | 'inspection'
  | 'transmission'
  | 'coolant'
  | 'air-filter'
  | 'spark-plugs'
  | 'other';

export interface Reminder {
  id: string;
  vehicleId: string;
  title: string;
  dueDate?: string;
  dueMileage?: number;
  isCompleted: boolean;
  createdAt: string;
}

export interface UserSettings {
  units: 'km' | 'miles';
  currency: string;
  notifications: boolean;
  isPremium: boolean;
}
