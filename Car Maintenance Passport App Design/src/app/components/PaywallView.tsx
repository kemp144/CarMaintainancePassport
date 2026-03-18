import { useNavigate } from 'react-router';
import { X, Check, Crown, Cloud, FileText, Infinity, Shield } from 'lucide-react';
import { Button } from './ui/button';
import { Card } from './ui/card';
import { saveSettings, getSettings } from '../utils/storage';
import { toast } from 'sonner';

const PREMIUM_FEATURES = [
  {
    icon: Infinity,
    title: 'Unlimited Vehicles',
    description: 'Add as many vehicles as you need',
  },
  {
    icon: FileText,
    title: 'PDF Export',
    description: 'Export complete service history as professional reports',
  },
  {
    icon: Cloud,
    title: 'Cloud Backup',
    description: 'Automatic backup and sync across all your devices',
  },
  {
    icon: Shield,
    title: 'Priority Support',
    description: 'Get help from our team faster',
  },
];

export function PaywallView() {
  const navigate = useNavigate();

  const handlePurchase = () => {
    // Simulate purchase - in a real app, this would integrate with payment system
    const settings = getSettings();
    saveSettings({ ...settings, isPremium: true });
    toast.success('Premium activated! (Demo)');
    navigate('/settings');
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950 flex flex-col">
      {/* Close Button */}
      <div className="px-6 pt-12 pb-4">
        <button
          onClick={() => navigate(-1)}
          className="w-10 h-10 rounded-full bg-slate-800 flex items-center justify-center text-slate-300 hover:bg-slate-700"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      {/* Hero Section */}
      <div className="px-6 py-8 text-center">
        <div className="w-20 h-20 rounded-full bg-gradient-to-br from-orange-500 to-orange-600 flex items-center justify-center mx-auto mb-6">
          <Crown className="w-10 h-10 text-white" />
        </div>
        <h1 className="text-4xl font-bold text-white mb-3">
          Upgrade to
          <br />
          Premium
        </h1>
        <p className="text-lg text-slate-400 max-w-md mx-auto">
          Get the most out of your Car Maintenance Passport
        </p>
      </div>

      {/* Features */}
      <div className="px-6 py-6 flex-1">
        <div className="space-y-4 max-w-lg mx-auto">
          {PREMIUM_FEATURES.map((feature, index) => {
            const Icon = feature.icon;
            return (
              <Card
                key={index}
                className="bg-slate-900 border-slate-800 p-5 hover:bg-slate-800/50 transition-colors"
              >
                <div className="flex gap-4">
                  <div className="w-12 h-12 rounded-xl bg-orange-500/10 flex items-center justify-center flex-shrink-0">
                    <Icon className="w-6 h-6 text-orange-500" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-lg font-semibold text-white mb-1">{feature.title}</h3>
                    <p className="text-sm text-slate-400">{feature.description}</p>
                  </div>
                  <Check className="w-5 h-5 text-green-500 flex-shrink-0 mt-1" />
                </div>
              </Card>
            );
          })}
        </div>
      </div>

      {/* Pricing & CTA */}
      <div className="px-6 py-8 bg-slate-900/50 backdrop-blur">
        <div className="max-w-lg mx-auto">
          {/* Pricing Options */}
          <div className="space-y-3 mb-6">
            {/* Annual Plan (Recommended) */}
            <Card className="bg-gradient-to-br from-orange-600 to-orange-700 border-orange-600 p-5 relative overflow-hidden">
              <div className="absolute top-3 right-3 px-3 py-1 bg-white/20 rounded-full">
                <span className="text-xs font-semibold text-white">BEST VALUE</span>
              </div>
              <div className="flex items-end gap-2 mb-2">
                <span className="text-4xl font-bold text-white">$29.99</span>
                <span className="text-orange-100 mb-1.5">/year</span>
              </div>
              <p className="text-orange-100 text-sm">Save 50% compared to monthly</p>
            </Card>

            {/* Monthly Plan */}
            <Card className="bg-slate-900 border-slate-700 p-5">
              <div className="flex items-end gap-2 mb-2">
                <span className="text-3xl font-bold text-white">$4.99</span>
                <span className="text-slate-400 mb-1">/month</span>
              </div>
              <p className="text-slate-400 text-sm">Billed monthly</p>
            </Card>
          </div>

          {/* Purchase Button */}
          <Button
            onClick={handlePurchase}
            className="w-full bg-orange-500 hover:bg-orange-600 text-white h-14 rounded-xl text-lg font-semibold mb-4"
          >
            Start Premium Now
          </Button>

          {/* Fine Print */}
          <p className="text-center text-xs text-slate-500 leading-relaxed">
            Subscriptions auto-renew. Cancel anytime.
            <br />
            By purchasing, you agree to our Terms of Service.
          </p>
        </div>
      </div>
    </div>
  );
}
