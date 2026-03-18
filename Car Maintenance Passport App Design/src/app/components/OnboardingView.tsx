import { useState } from 'react';
import { useNavigate } from 'react-router';
import { motion, AnimatePresence } from 'motion/react';
import { Car, FileText, Bell, ArrowRight } from 'lucide-react';
import { Button } from './ui/button';
import { setOnboardingComplete } from '../utils/storage';

const onboardingSteps = [
  {
    icon: Car,
    title: 'Track All Your Vehicles',
    description: 'Manage maintenance history for all your cars and motorcycles in one secure place.',
  },
  {
    icon: FileText,
    title: 'Organize Service Records',
    description: 'Keep detailed logs of every service with photos, receipts, and notes. Increase resale value with complete history.',
  },
  {
    icon: Bell,
    title: 'Never Miss Maintenance',
    description: 'Set reminders based on time or mileage. Get notified when service is due.',
  },
];

export function OnboardingView() {
  const [currentStep, setCurrentStep] = useState(0);
  const navigate = useNavigate();

  const handleNext = () => {
    if (currentStep < onboardingSteps.length - 1) {
      setCurrentStep(currentStep + 1);
    } else {
      setOnboardingComplete();
      navigate('/');
    }
  };

  const handleSkip = () => {
    setOnboardingComplete();
    navigate('/');
  };

  const step = onboardingSteps[currentStep];
  const Icon = step.icon;

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950 flex flex-col items-center justify-center px-6 py-12">
      <div className="w-full max-w-md">
        {/* Progress indicators */}
        <div className="flex gap-2 justify-center mb-16">
          {onboardingSteps.map((_, index) => (
            <div
              key={index}
              className={`h-1 rounded-full transition-all ${
                index === currentStep
                  ? 'w-8 bg-orange-500'
                  : index < currentStep
                  ? 'w-4 bg-orange-500/50'
                  : 'w-4 bg-slate-700'
              }`}
            />
          ))}
        </div>

        <AnimatePresence mode="wait">
          <motion.div
            key={currentStep}
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -20 }}
            transition={{ duration: 0.3 }}
            className="text-center"
          >
            {/* Icon */}
            <div className="mb-8 flex justify-center">
              <div className="w-24 h-24 rounded-full bg-gradient-to-br from-orange-500 to-orange-600 flex items-center justify-center">
                <Icon className="w-12 h-12 text-white" />
              </div>
            </div>

            {/* Title */}
            <h1 className="text-3xl font-bold text-white mb-4">{step.title}</h1>

            {/* Description */}
            <p className="text-lg text-slate-400 leading-relaxed mb-12">{step.description}</p>
          </motion.div>
        </AnimatePresence>

        {/* Buttons */}
        <div className="space-y-3">
          <Button
            onClick={handleNext}
            className="w-full bg-orange-500 hover:bg-orange-600 text-white h-14 text-lg rounded-xl"
          >
            {currentStep < onboardingSteps.length - 1 ? (
              <>
                Next
                <ArrowRight className="ml-2 w-5 h-5" />
              </>
            ) : (
              'Get Started'
            )}
          </Button>

          {currentStep < onboardingSteps.length - 1 && (
            <Button
              onClick={handleSkip}
              variant="ghost"
              className="w-full text-slate-400 hover:text-white h-14 text-base"
            >
              Skip
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}
