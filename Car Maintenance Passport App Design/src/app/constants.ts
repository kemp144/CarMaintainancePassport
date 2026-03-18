export const APP_NAME = 'Car Maintenance Passport';
export const APP_VERSION = '1.0.0';

export const CURRENCY_OPTIONS = [
  { value: 'USD', label: 'USD ($)', symbol: '$' },
  { value: 'EUR', label: 'EUR (€)', symbol: '€' },
  { value: 'GBP', label: 'GBP (£)', symbol: '£' },
  { value: 'CAD', label: 'CAD ($)', symbol: '$' },
  { value: 'AUD', label: 'AUD ($)', symbol: '$' },
];

export const UNIT_OPTIONS = [
  { value: 'km', label: 'Kilometers (km)' },
  { value: 'miles', label: 'Miles (mi)' },
];

export const SERVICE_CATEGORIES = [
  { value: 'oil-change', label: 'Oil Change', icon: '🛢️' },
  { value: 'brake-replacement', label: 'Brake Replacement', icon: '🔧' },
  { value: 'tire-rotation', label: 'Tire Rotation', icon: '🔄' },
  { value: 'tire-replacement', label: 'Tire Replacement', icon: '🛞' },
  { value: 'battery', label: 'Battery', icon: '🔋' },
  { value: 'inspection', label: 'Inspection', icon: '🔍' },
  { value: 'transmission', label: 'Transmission', icon: '⚙️' },
  { value: 'coolant', label: 'Coolant', icon: '❄️' },
  { value: 'air-filter', label: 'Air Filter', icon: '💨' },
  { value: 'spark-plugs', label: 'Spark Plugs', icon: '⚡' },
  { value: 'other', label: 'Other', icon: '🔨' },
] as const;

export const REMINDER_INTERVALS = {
  mileage: [
    { value: 5000, label: '5,000 km' },
    { value: 10000, label: '10,000 km' },
    { value: 15000, label: '15,000 km' },
    { value: 20000, label: '20,000 km' },
    { value: 25000, label: '25,000 km' },
    { value: 50000, label: '50,000 km' },
  ],
  months: [
    { value: 1, label: '1 month' },
    { value: 3, label: '3 months' },
    { value: 6, label: '6 months' },
    { value: 12, label: '1 year' },
    { value: 24, label: '2 years' },
  ],
};

export const PREMIUM_FEATURES = [
  'Unlimited vehicles',
  'PDF export',
  'Cloud backup and sync',
  'Priority support',
  'Advanced analytics',
  'Custom service categories',
] as const;
