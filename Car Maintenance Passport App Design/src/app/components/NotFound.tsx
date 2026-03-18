import { useNavigate } from 'react-router';
import { AlertCircle } from 'lucide-react';
import { Button } from './ui/button';

export function NotFound() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center px-6">
      <div className="text-center max-w-md">
        <div className="w-20 h-20 rounded-full bg-slate-800/50 flex items-center justify-center mx-auto mb-6">
          <AlertCircle className="w-10 h-10 text-slate-600" />
        </div>
        <h1 className="text-3xl font-bold text-white mb-3">Page Not Found</h1>
        <p className="text-slate-400 mb-8">
          The page you're looking for doesn't exist or has been moved.
        </p>
        <Button
          onClick={() => navigate('/')}
          className="bg-orange-500 hover:bg-orange-600 text-white rounded-xl h-12 px-8"
        >
          Go to Garage
        </Button>
      </div>
    </div>
  );
}
