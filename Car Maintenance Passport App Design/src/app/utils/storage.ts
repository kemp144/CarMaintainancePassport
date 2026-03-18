import { Vehicle, ServiceEntry, Reminder, UserSettings } from '../types';

const STORAGE_KEYS = {
  VEHICLES: 'car-passport-vehicles',
  SERVICES: 'car-passport-services',
  REMINDERS: 'car-passport-reminders',
  SETTINGS: 'car-passport-settings',
  ONBOARDING_COMPLETE: 'car-passport-onboarding',
};

// Vehicles
export const getVehicles = (): Vehicle[] => {
  const data = localStorage.getItem(STORAGE_KEYS.VEHICLES);
  return data ? JSON.parse(data) : [];
};

export const saveVehicles = (vehicles: Vehicle[]): void => {
  localStorage.setItem(STORAGE_KEYS.VEHICLES, JSON.stringify(vehicles));
};

export const addVehicle = (vehicle: Vehicle): void => {
  const vehicles = getVehicles();
  vehicles.push(vehicle);
  saveVehicles(vehicles);
};

export const updateVehicle = (id: string, updates: Partial<Vehicle>): void => {
  const vehicles = getVehicles();
  const index = vehicles.findIndex((v) => v.id === id);
  if (index !== -1) {
    vehicles[index] = { ...vehicles[index], ...updates };
    saveVehicles(vehicles);
  }
};

export const deleteVehicle = (id: string): void => {
  const vehicles = getVehicles().filter((v) => v.id !== id);
  saveVehicles(vehicles);
  // Also delete related services and reminders
  const services = getServiceEntries().filter((s) => s.vehicleId !== id);
  saveServiceEntries(services);
  const reminders = getReminders().filter((r) => r.vehicleId !== id);
  saveReminders(reminders);
};

// Service Entries
export const getServiceEntries = (): ServiceEntry[] => {
  const data = localStorage.getItem(STORAGE_KEYS.SERVICES);
  return data ? JSON.parse(data) : [];
};

export const saveServiceEntries = (entries: ServiceEntry[]): void => {
  localStorage.setItem(STORAGE_KEYS.SERVICES, JSON.stringify(entries));
};

export const addServiceEntry = (entry: ServiceEntry): void => {
  const entries = getServiceEntries();
  entries.push(entry);
  saveServiceEntries(entries);
};

export const updateServiceEntry = (id: string, updates: Partial<ServiceEntry>): void => {
  const entries = getServiceEntries();
  const index = entries.findIndex((e) => e.id === id);
  if (index !== -1) {
    entries[index] = { ...entries[index], ...updates };
    saveServiceEntries(entries);
  }
};

export const deleteServiceEntry = (id: string): void => {
  const entries = getServiceEntries().filter((e) => e.id !== id);
  saveServiceEntries(entries);
};

export const getServiceEntriesForVehicle = (vehicleId: string): ServiceEntry[] => {
  return getServiceEntries()
    .filter((e) => e.vehicleId === vehicleId)
    .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
};

// Reminders
export const getReminders = (): Reminder[] => {
  const data = localStorage.getItem(STORAGE_KEYS.REMINDERS);
  return data ? JSON.parse(data) : [];
};

export const saveReminders = (reminders: Reminder[]): void => {
  localStorage.setItem(STORAGE_KEYS.REMINDERS, JSON.stringify(reminders));
};

export const addReminder = (reminder: Reminder): void => {
  const reminders = getReminders();
  reminders.push(reminder);
  saveReminders(reminders);
};

export const updateReminder = (id: string, updates: Partial<Reminder>): void => {
  const reminders = getReminders();
  const index = reminders.findIndex((r) => r.id === id);
  if (index !== -1) {
    reminders[index] = { ...reminders[index], ...updates };
    saveReminders(reminders);
  }
};

export const deleteReminder = (id: string): void => {
  const reminders = getReminders().filter((r) => r.id !== id);
  saveReminders(reminders);
};

// Settings
export const getSettings = (): UserSettings => {
  const data = localStorage.getItem(STORAGE_KEYS.SETTINGS);
  return data
    ? JSON.parse(data)
    : { units: 'km', currency: 'USD', notifications: true, isPremium: false };
};

export const saveSettings = (settings: UserSettings): void => {
  localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify(settings));
};

// Onboarding
export const isOnboardingComplete = (): boolean => {
  return localStorage.getItem(STORAGE_KEYS.ONBOARDING_COMPLETE) === 'true';
};

export const setOnboardingComplete = (): void => {
  localStorage.setItem(STORAGE_KEYS.ONBOARDING_COMPLETE, 'true');
};

// Utility to generate unique IDs
export const generateId = (): string => {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
};
