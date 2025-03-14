import React from 'react';
import { createRoot } from 'react-dom/client';

interface FluidProps {
  name: string;
}

const Fluid = ({ name }: FluidProps) => {
  return (
    <div className="flex justify-center items-center h-screen rounded-lg">
      <div className="bg-slate-900 rounded-lg p-2">
        <i className="text-3xl fa-solid fa-droplet text-teal-400"></i>
        &nbsp;
        <i className="text-3xl fa-solid fa-droplet text-fuchsia-600"></i>
        <br />
        <i className="text-3xl fa-solid fa-droplet text-amber-300"></i>
        &nbsp;
        <i className="text-3xl fa-solid fa-droplet text-blue-600"></i>
        <br />
        <div className="text-white text-center">{name}</div>
      </div>
    </div>
  );
};

const root = createRoot(document.getElementById('root') as HTMLElement);
root.render(<Fluid name="Fluid" />);
