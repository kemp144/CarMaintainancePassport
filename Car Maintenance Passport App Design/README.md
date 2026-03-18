# Car Maintenance Passport

A modern, mobile-first progressive web application for tracking vehicle maintenance history, service records, and reminders.

## Features

### Core Features
- **Multi-Vehicle Management**: Track maintenance for all your vehicles in one place
- **Service Log**: Detailed records of all maintenance work with dates, mileage, costs, and notes
- **Smart Reminders**: Set time-based or mileage-based reminders for upcoming maintenance
- **Document Storage**: Attach photos and receipts to service records
- **Timeline View**: Chronological view of all services across all vehicles
- **Data Export**: Export service history as professional PDF reports (Premium)

### Premium Features
- Unlimited vehicles
- PDF export functionality
- Cloud backup and sync
- Priority support

## Technology Stack

- **React 18.3** - UI library
- **TypeScript** - Type safety
- **React Router 7** - Navigation and routing
- **Tailwind CSS v4** - Styling
- **Motion** - Smooth animations
- **date-fns** - Date formatting
- **Lucide React** - Icon system
- **Sonner** - Toast notifications
- **Radix UI** - Accessible UI components

## Project Structure

```
src/
├── app/
│   ├── components/
│   │   ├── OnboardingView.tsx          # 3-screen onboarding flow
│   │   ├── MainLayout.tsx              # Bottom tab navigation
│   │   ├── GarageView.tsx              # Vehicle list (main screen)
│   │   ├── VehicleDetailView.tsx       # Individual vehicle details
│   │   ├── VehicleFormView.tsx         # Add/edit vehicle
│   │   ├── ServiceEntryFormView.tsx    # Add/edit service
│   │   ├── ServiceDetailView.tsx       # Service record details
│   │   ├── TimelineView.tsx            # All services timeline
│   │   ├── RemindersView.tsx           # Maintenance reminders
│   │   ├── ReminderFormView.tsx        # Add/edit reminder
│   │   ├── SettingsView.tsx            # App settings
│   │   ├── PaywallView.tsx             # Premium upgrade screen
│   │   └── ui/                         # Reusable UI components
│   ├── data/
│   │   └── mockData.ts                 # Sample data for demo
│   ├── utils/
│   │   ├── storage.ts                  # localStorage utilities
│   │   └── formatters.ts               # Formatting helpers
│   ├── types.ts                        # TypeScript interfaces
│   ├── routes.ts                       # Route configuration
│   └── App.tsx                         # Main app component
└── styles/
    ├── fonts.css
    ├── index.css
    ├── tailwind.css
    └── theme.css                       # Design tokens and theme

```

## Design System

### Colors
- **Background**: Slate 950 (dark mode primary)
- **Cards/Surfaces**: Slate 900
- **Accent**: Orange 500-600
- **Text**: White/Slate 400 hierarchy

### Typography
- System font stack optimized for iOS
- Clean hierarchy with proper sizing

### Components
- Card-based UI for easy scanning
- Bottom tab navigation (iOS pattern)
- Floating action buttons for primary actions
- Full-screen modals for forms

## Data Model

### Vehicle
- Basic info (make, model, year)
- VIN and license plate (optional)
- Photo

### Service Entry
- Date and mileage
- Service type (11 categories)
- Cost and currency
- Notes
- Photo attachments

### Reminder
- Linked to specific vehicle
- Date-based or mileage-based triggers
- Completion status

### Settings
- Units (km/miles)
- Currency preference
- Notifications toggle
- Premium status

## Local Storage

All data is stored in browser localStorage:
- Persists between sessions
- No backend required for demo
- Easy to upgrade to cloud sync with Supabase

## Key User Flows

1. **Onboarding**: 3 screens → Skip or complete → Main app
2. **Add Vehicle**: Garage → + Button → Form → Save
3. **Log Service**: Vehicle Details → Add Service → Fill form → Save
4. **Set Reminder**: Reminders → + Button → Select vehicle & criteria → Save
5. **Upgrade Premium**: Settings → Premium card → Paywall → Purchase

## Mobile Optimization

- Designed for iPhone 17 Pro as reference
- Responsive to all screen sizes
- Touch-optimized tap targets (44px minimum)
- Smooth animations and transitions
- Bottom navigation for thumb-friendly access
- Fixed positioning for critical UI elements

## Future Enhancements

- Push notifications for reminders
- Cloud sync with Supabase
- Multi-language support
- Dark/light theme toggle
- Export to email
- Service cost analytics
- Fuel economy tracking
- Insurance/registration expiry tracking

## Development

The app uses React Router's data mode with client-side routing. All routes are defined in `routes.ts`.

To add a new screen:
1. Create component in `components/`
2. Add route to `routes.ts`
3. Link from existing screens

## Demo Data

The app includes sample data for 3 vehicles with service history and reminders. This data loads automatically on first run and persists in localStorage.

---

Built with ❤️ for car enthusiasts and anyone who wants to keep their vehicles in top shape.
