import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'AlmaOficial.Alma',
  appName: 'Alma',
  webDir: 'dist',
  server: {
    androidScheme: 'https',
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 2000,
      backgroundColor: '#6B46C1',
      androidSplashResourceName: 'splash',
      androidScaleType: 'CENTER_CROP',
      showSpinner: false,
    },
    StatusBar: {
      style: 'DARK',
      backgroundColor: '#6B46C1',
    },
  },
};

export default config;
