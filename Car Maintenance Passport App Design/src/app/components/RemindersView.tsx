import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { Plus, Bell, Calendar, Gauge, Car, CheckCircle2 } from 'lucide-react';
import { Button } from './ui/button';
import { Card } from './ui/card';
import { Reminder, Vehicle } from '../types';
import { getReminders, getVehicles, updateReminder } from '../utils/storage';
import { format, isBefore } from 'date-fns';

export function RemindersView() {
  const [reminders, setReminders] = useState<Reminder[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const navigate = useNavigate();

  useEffect(() => {
    loadData();
  }, []);

  const loadData = () => {
    const allReminders = getReminders().sort((a, b) => {
      // Sort by due date/mileage
      if (a.dueDate && b.dueDate) {
        return new Date(a.dueDate).getTime() - new Date(b.dueDate).getTime();
      }
      if (a.dueMileage && b.dueMileage) {
        return a.dueMileage - b.dueMileage;
      }
      return 0;
    });
    setReminders(allReminders);
    setVehicles(getVehicles());
  };

  useEffect(() => {
    const handleStorageChange = () => {
      loadData();
    };

    window.addEventListener('storage-update', handleStorageChange);
    return () => window.removeEventListener('storage-update', handleStorageChange);
  }, []);

  const getVehicleForReminder = (vehicleId: string): Vehicle | undefined => {
    return vehicles.find((v) => v.id === vehicleId);
  };

  const toggleComplete = (reminder: Reminder) => {
    updateReminder(reminder.id, { isCompleted: !reminder.isCompleted });
    window.dispatchEvent(new Event('storage-update'));
  };

  const isOverdue = (reminder: Reminder): boolean => {
    if (reminder.isCompleted) return false;
    if (reminder.dueDate) {
      return isBefore(new Date(reminder.dueDate), new Date());
    }
    return false;
  };

  const activeReminders = reminders.filter((r) => !r.isCompleted);
  const completedReminders = reminders.filter((r) => r.isCompleted);

  return (
    <div className="min-h-screen bg-slate-950">
      {/* Header */}
      <div className="bg-gradient-to-b from-slate-900 to-slate-950 px-6 pt-12 pb-8">
        <h1 className="text-3xl font-bold text-white mb-2">Reminders</h1>
        <p className="text-slate-400">
          {activeReminders.length === 0
            ? 'No active reminders'
            : `${activeReminders.length} active ${
                activeReminders.length === 1 ? 'reminder' : 'reminders'
              }`}
        </p>
      </div>

      {/* Content */}
      <div className="px-6 pt-4 pb-6">
        {reminders.length === 0 ? (
          /* Empty State */
          <div className="flex flex-col items-center justify-center py-16 px-6">
            <div className="w-24 h-24 rounded-full bg-slate-800/50 flex items-center justify-center mb-6">
              <Bell className="w-12 h-12 text-slate-600" />
            </div>
            <h2 className="text-xl font-semibold text-white mb-2">No Reminders Yet</h2>
            <p className="text-slate-400 text-center mb-8 max-w-xs">
              Set up maintenance reminders to stay on top of your vehicle care.
            </p>
            <Button
              onClick={() => navigate('/reminder/new')}
              className="bg-orange-500 hover:bg-orange-600 text-white rounded-xl h-12 px-8"
            >
              <Plus className="mr-2 w-5 h-5" />
              Add Reminder
            </Button>
          </div>
        ) : (
          <div className="space-y-6">
            {/* Active Reminders */}
            {activeReminders.length > 0 && (
              <div className="space-y-3">
                <h2 className="text-sm font-semibold text-slate-400 uppercase tracking-wide">
                  Active
                </h2>
                {activeReminders.map((reminder) => {
                  const vehicle = getVehicleForReminder(reminder.vehicleId);
                  if (!vehicle) return null;

                  const overdue = isOverdue(reminder);

                  return (
                    <Card
                      key={reminder.id}
                      onClick={() => navigate(`/reminder/${reminder.id}`)}
                      className={`border p-4 cursor-pointer transition-colors ${
                        overdue
                          ? 'bg-red-950/30 border-red-900/50 hover:bg-red-950/40'
                          : 'bg-slate-900 border-slate-800 hover:bg-slate-800/80'
                      }`}
                    >
                      <div className="flex items-start gap-3">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            toggleComplete(reminder);
                          }}
                          className={`w-6 h-6 rounded-full border-2 flex items-center justify-center flex-shrink-0 mt-0.5 ${
                            overdue
                              ? 'border-red-500/50 hover:border-red-500'
                              : 'border-slate-600 hover:border-orange-500'
                          }`}
                        >
                          {reminder.isCompleted && (
                            <CheckCircle2 className="w-5 h-5 text-orange-500" />
                          )}
                        </button>

                        <div className="flex-1 min-w-0">
                          {/* Title */}
                          <h3 className={`font-semibold mb-1 ${overdue ? 'text-red-400' : 'text-white'}`}>
                            {reminder.title}
                          </h3>

                          {/* Vehicle */}
                          <div className="flex items-center gap-2 text-sm text-slate-400 mb-2">
                            <Car className="w-3.5 h-3.5" />
                            <span>
                              {vehicle.make} {vehicle.model}
                            </span>
                          </div>

                          {/* Due info */}
                          <div className="flex flex-wrap gap-3">
                            {reminder.dueDate && (
                              <div className="flex items-center gap-1.5 text-sm">
                                <Calendar className={`w-3.5 h-3.5 ${overdue ? 'text-red-500' : 'text-orange-500'}`} />
                                <span className={overdue ? 'text-red-400' : 'text-slate-300'}>
                                  {format(new Date(reminder.dueDate), 'MMM d, yyyy')}
                                  {overdue && ' (Overdue)'}
                                </span>
                              </div>
                            )}
                            {reminder.dueMileage && (
                              <div className="flex items-center gap-1.5 text-sm text-slate-300">
                                <Gauge className="w-3.5 h-3.5 text-orange-500" />
                                <span>{reminder.dueMileage.toLocaleString()} km</span>
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    </Card>
                  );
                })}
              </div>
            )}

            {/* Completed Reminders */}
            {completedReminders.length > 0 && (
              <div className="space-y-3">
                <h2 className="text-sm font-semibold text-slate-400 uppercase tracking-wide">
                  Completed
                </h2>
                {completedReminders.map((reminder) => {
                  const vehicle = getVehicleForReminder(reminder.vehicleId);
                  if (!vehicle) return null;

                  return (
                    <Card
                      key={reminder.id}
                      onClick={() => navigate(`/reminder/${reminder.id}`)}
                      className="bg-slate-900/50 border-slate-800 p-4 cursor-pointer hover:bg-slate-800/50 transition-colors opacity-60"
                    >
                      <div className="flex items-start gap-3">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            toggleComplete(reminder);
                          }}
                          className="w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5"
                        >
                          <CheckCircle2 className="w-5 h-5 text-green-500" />
                        </button>

                        <div className="flex-1 min-w-0">
                          <h3 className="font-semibold text-white mb-1 line-through">
                            {reminder.title}
                          </h3>
                          <div className="flex items-center gap-2 text-sm text-slate-400">
                            <Car className="w-3.5 h-3.5" />
                            <span>
                              {vehicle.make} {vehicle.model}
                            </span>
                          </div>
                        </div>
                      </div>
                    </Card>
                  );
                })}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Floating Add Button */}
      {reminders.length > 0 && (
        <button
          onClick={() => navigate('/reminder/new')}
          className="fixed bottom-24 right-6 w-14 h-14 bg-orange-500 hover:bg-orange-600 text-white rounded-full shadow-lg flex items-center justify-center transition-colors"
        >
          <Plus className="w-6 h-6" />
        </button>
      )}
    </div>
  );
}
