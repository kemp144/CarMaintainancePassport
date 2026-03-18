import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import {
  User,
  Ruler,
  Bell,
  Download,
  Crown,
  ChevronRight,
  Info,
  Shield,
  Mail,
} from 'lucide-react';
import { Card } from './ui/card';
import { Switch } from './ui/switch';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { UserSettings } from '../types';
import { getSettings, saveSettings } from '../utils/storage';
import { toast } from 'sonner';

export function SettingsView() {
  const [settings, setSettings] = useState<UserSettings>({
    units: 'km',
    currency: 'USD',
    notifications: true,
    isPremium: false,
  });
  const navigate = useNavigate();

  useEffect(() => {
    const loadedSettings = getSettings();
    setSettings(loadedSettings);
  }, []);

  const updateSetting = (key: keyof UserSettings, value: any) => {
    const newSettings = { ...settings, [key]: value };
    setSettings(newSettings);
    saveSettings(newSettings);
    toast.success('Settings updated');
  };

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Header */}
      <div className="bg-gradient-to-b from-slate-900 to-slate-950 px-6 pt-12 pb-8">
        <h1 className="text-3xl font-bold text-white mb-2">Settings</h1>
        <p className="text-slate-400">Manage your preferences</p>
      </div>

      {/* Content */}
      <div className="px-6 pt-4 pb-6 space-y-6">
        {/* Premium Card */}
        {!settings.isPremium && (
          <Card
            onClick={() => navigate('/paywall')}
            className="bg-gradient-to-br from-orange-600 to-orange-700 border-orange-600 p-6 cursor-pointer hover:from-orange-500 hover:to-orange-600 transition-all"
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-white/20 flex items-center justify-center">
                  <Crown className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-white">Upgrade to Premium</h3>
                  <p className="text-sm text-orange-100">Unlock all features</p>
                </div>
              </div>
              <ChevronRight className="w-5 h-5 text-white" />
            </div>
          </Card>
        )}

        {settings.isPremium && (
          <Card className="bg-slate-900 border-slate-800 p-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-full bg-orange-500/20 flex items-center justify-center">
                <Crown className="w-6 h-6 text-orange-500" />
              </div>
              <div>
                <h3 className="text-lg font-semibold text-white">Premium Member</h3>
                <p className="text-sm text-slate-400">Thank you for your support!</p>
              </div>
            </div>
          </Card>
        )}

        {/* Account Section */}
        <div className="space-y-3">
          <h2 className="text-sm font-semibold text-slate-400 uppercase tracking-wide px-1">
            Account
          </h2>
          <Card className="bg-slate-900 border-slate-800">
            <button className="w-full flex items-center justify-between p-4 hover:bg-slate-800/50 transition-colors">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-orange-500/20 flex items-center justify-center">
                  <User className="w-5 h-5 text-orange-500" />
                </div>
                <div className="text-left">
                  <p className="text-white font-medium">Profile</p>
                  <p className="text-sm text-slate-400">Manage your account</p>
                </div>
              </div>
              <ChevronRight className="w-5 h-5 text-slate-500" />
            </button>
          </Card>
        </div>

        {/* Preferences Section */}
        <div className="space-y-3">
          <h2 className="text-sm font-semibold text-slate-400 uppercase tracking-wide px-1">
            Preferences
          </h2>

          {/* Units */}
          <Card className="bg-slate-900 border-slate-800 p-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center">
                  <Ruler className="w-5 h-5 text-orange-500" />
                </div>
                <div>
                  <p className="text-white font-medium">Units</p>
                  <p className="text-sm text-slate-400">Distance measurement</p>
                </div>
              </div>
              <Select
                value={settings.units}
                onValueChange={(value: 'km' | 'miles') => updateSetting('units', value)}
              >
                <SelectTrigger className="w-28 bg-slate-800 border-slate-700 text-white h-9">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className="bg-slate-800 border-slate-700">
                  <SelectItem value="km" className="text-white">
                    km
                  </SelectItem>
                  <SelectItem value="miles" className="text-white">
                    miles
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
          </Card>

          {/* Notifications */}
          <Card className="bg-slate-900 border-slate-800 p-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center">
                  <Bell className="w-5 h-5 text-orange-500" />
                </div>
                <div>
                  <p className="text-white font-medium">Notifications</p>
                  <p className="text-sm text-slate-400">Reminder alerts</p>
                </div>
              </div>
              <Switch
                checked={settings.notifications}
                onCheckedChange={(checked) => updateSetting('notifications', checked)}
              />
            </div>
          </Card>
        </div>

        {/* Data Section */}
        <div className="space-y-3">
          <h2 className="text-sm font-semibold text-slate-400 uppercase tracking-wide px-1">
            Data
          </h2>

          {/* Export Data */}
          <Card className="bg-slate-900 border-slate-800">
            <button
              onClick={() => toast.info('PDF export available in Premium')}
              className="w-full flex items-center justify-between p-4 hover:bg-slate-800/50 transition-colors"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center">
                  <Download className="w-5 h-5 text-orange-500" />
                </div>
                <div className="text-left">
                  <p className="text-white font-medium">Export Service History</p>
                  <p className="text-sm text-slate-400">Download as PDF</p>
                </div>
              </div>
              {!settings.isPremium && (
                <div className="flex items-center gap-2">
                  <Crown className="w-4 h-4 text-orange-500" />
                  <span className="text-xs text-orange-500">Premium</span>
                </div>
              )}
            </button>
          </Card>
        </div>

        {/* About Section */}
        <div className="space-y-3">
          <h2 className="text-sm font-semibold text-slate-400 uppercase tracking-wide px-1">
            About
          </h2>

          <Card className="bg-slate-900 border-slate-800">
            <button className="w-full flex items-center justify-between p-4 hover:bg-slate-800/50 transition-colors border-b border-slate-800 last:border-b-0">
              <div className="flex items-center gap-3">
                <Info className="w-5 h-5 text-slate-400" />
                <p className="text-white">About</p>
              </div>
              <ChevronRight className="w-5 h-5 text-slate-500" />
            </button>

            <button className="w-full flex items-center justify-between p-4 hover:bg-slate-800/50 transition-colors border-b border-slate-800 last:border-b-0">
              <div className="flex items-center gap-3">
                <Shield className="w-5 h-5 text-slate-400" />
                <p className="text-white">Privacy Policy</p>
              </div>
              <ChevronRight className="w-5 h-5 text-slate-500" />
            </button>

            <button className="w-full flex items-center justify-between p-4 hover:bg-slate-800/50 transition-colors">
              <div className="flex items-center gap-3">
                <Mail className="w-5 h-5 text-slate-400" />
                <p className="text-white">Contact Support</p>
              </div>
              <ChevronRight className="w-5 h-5 text-slate-500" />
            </button>
          </Card>
        </div>

        {/* Version */}
        <p className="text-center text-sm text-slate-500 py-4">
          Car Maintenance Passport v1.0.0
        </p>
      </div>
    </div>
  );
}
