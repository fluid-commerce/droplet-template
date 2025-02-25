// Example with type annotations
interface AppConfig {
  environment: string;
  debug: boolean;
}

const config: AppConfig = {
  environment: process.env.NODE_ENV || 'development',
  debug: true
};

// TODO: Remove this after testing
console.log('Vite ⚡️ Rails with TypeScript', config);
