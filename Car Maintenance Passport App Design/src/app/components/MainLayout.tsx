import { Outlet, useLocation, useNavigate } from 'react-router';
import { Car, Clock, Bell, Settings } from 'lucide-react';

const tabs = [
  { id: 'garage', label: 'Garage', icon: Car, path: '/' },
  { id: 'timeline', label: 'Timeline', icon: Clock, path: '/timeline' },
  { id: 'reminders', label: 'Reminders', icon: Bell, path: '/reminders' },
  { id: 'settings', label: 'Settings', icon: Settings, path: '/settings' },
];

export function MainLayout() {
  const location = useLocation();
  const navigate = useNavigate();

  // Determine active tab based on current path
  const getActiveTab = () => {
    const currentPath = location.pathname;
    if (currentPath === '/') return 'garage';
    if (currentPath.startsWith('/timeline')) return 'timeline';
    if (currentPath.startsWith('/reminders')) return 'reminders';
    if (currentPath.startsWith('/settings')) return 'settings';
    return 'garage';
  };

  const activeTab = getActiveTab();

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col max-w-md mx-auto">
      {/* Main content area */}
      <div className="flex-1 overflow-y-auto pb-20">
        <Outlet />
      </div>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 max-w-md mx-auto bg-slate-900/95 backdrop-blur-lg border-t border-slate-800">
        <div className="flex items-center justify-around h-20 px-4">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;

            return (
              <button
                key={tab.id}
                onClick={() => navigate(tab.path)}
                className="flex flex-col items-center justify-center gap-1 flex-1 py-2 relative"
              >
                {/* Active indicator */}
                {isActive && (
                  <div className="absolute top-0 left-1/2 -translate-x-1/2 w-12 h-1 bg-orange-500 rounded-full" />
                )}

                {/* Icon */}
                <Icon
                  className={`w-6 h-6 transition-colors ${
                    isActive ? 'text-orange-500' : 'text-slate-400'
                  }`}
                />

                {/* Label */}
                <span
                  className={`text-xs font-medium transition-colors ${
                    isActive ? 'text-white' : 'text-slate-400'
                  }`}
                >
                  {tab.label}
                </span>
              </button>
            );
          })}
        </div>
      </nav>
    </div>
  );
}
