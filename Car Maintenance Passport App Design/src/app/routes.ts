import { createBrowserRouter } from 'react-router';
import { OnboardingView } from './components/OnboardingView';
import { MainLayout } from './components/MainLayout';
import { GarageView } from './components/GarageView';
import { VehicleFormView } from './components/VehicleFormView';
import { VehicleDetailView } from './components/VehicleDetailView';
import { ServiceEntryFormView } from './components/ServiceEntryFormView';
import { ServiceDetailView } from './components/ServiceDetailView';
import { TimelineView } from './components/TimelineView';
import { RemindersView } from './components/RemindersView';
import { ReminderFormView } from './components/ReminderFormView';
import { SettingsView } from './components/SettingsView';
import { PaywallView } from './components/PaywallView';
import { NotFound } from './components/NotFound';
import { isOnboardingComplete } from './utils/storage';
import { mockVehicles, mockServiceEntries, mockReminders } from './data/mockData';
import { getVehicles, saveVehicles, getServiceEntries, saveServiceEntries, getReminders, saveReminders } from './utils/storage';

// Initialize with mock data if no data exists
const initializeMockData = () => {
  if (getVehicles().length === 0) {
    saveVehicles(mockVehicles);
  }
  if (getServiceEntries().length === 0) {
    saveServiceEntries(mockServiceEntries);
  }
  if (getReminders().length === 0) {
    saveReminders(mockReminders);
  }
};

// Check onboarding and initialize data
const shouldShowOnboarding = () => {
  const onboardingDone = isOnboardingComplete();
  if (!onboardingDone) {
    initializeMockData();
  }
  return !onboardingDone;
};

export const router = createBrowserRouter([
  {
    path: '/onboarding',
    Component: OnboardingView,
  },
  {
    path: '/paywall',
    Component: PaywallView,
  },
  {
    path: '/',
    Component: MainLayout,
    loader: () => {
      if (shouldShowOnboarding()) {
        return Response.redirect('/onboarding');
      }
      return null;
    },
    children: [
      {
        index: true,
        Component: GarageView,
      },
      {
        path: 'timeline',
        Component: TimelineView,
      },
      {
        path: 'reminders',
        Component: RemindersView,
      },
      {
        path: 'settings',
        Component: SettingsView,
      },
    ],
  },
  {
    path: '/vehicle/new',
    Component: VehicleFormView,
  },
  {
    path: '/vehicle/:id/edit',
    Component: VehicleFormView,
  },
  {
    path: '/vehicle/:id',
    Component: VehicleDetailView,
  },
  {
    path: '/vehicle/:vehicleId/service/new',
    Component: ServiceEntryFormView,
  },
  {
    path: '/vehicle/:vehicleId/service/:serviceId/edit',
    Component: ServiceEntryFormView,
  },
  {
    path: '/service/:serviceId',
    Component: ServiceDetailView,
  },
  {
    path: '/reminder/new',
    Component: ReminderFormView,
  },
  {
    path: '/reminder/:id',
    Component: ReminderFormView,
  },
  {
    path: '*',
    Component: NotFound,
  },
]);