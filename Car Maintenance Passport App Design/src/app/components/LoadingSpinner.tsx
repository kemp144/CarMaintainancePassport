export function LoadingSpinner() {
  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center">
      <div className="w-12 h-12 border-4 border-slate-700 border-t-orange-500 rounded-full animate-spin"></div>
    </div>
  );
}
