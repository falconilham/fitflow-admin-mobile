import React from 'react';
import { StatusBar } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { Provider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { store, persistor } from './src/store';
import AppNavigator from './src/navigation/AppNavigator';

function App() {
  return (
    <Provider store={store}>
      <PersistGate loading={null} persistor={persistor}>
        <SafeAreaProvider>
          <StatusBar barStyle="light-content" backgroundColor="#111" />
          <NavigationContainer>
            <AppNavigator />
          </NavigationContainer>
        </SafeAreaProvider>
      </PersistGate>
    </Provider>
  );
}

export default App;
