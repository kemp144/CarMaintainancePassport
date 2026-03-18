import { ServiceType } from '../types';

export const SERVICE_TYPE_LABELS: Record<ServiceType, string> = {
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

export function formatCurrency(amount: number, currency: string = 'USD'): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(amount);
}

export function formatMileage(mileage: number, units: 'km' | 'miles' = 'km'): string {
  return `${mileage.toLocaleString()} ${units}`;
}
