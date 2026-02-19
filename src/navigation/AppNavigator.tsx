import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';

import LoginScreen from '../screens/auth/LoginScreen';
import MainNavigator from './MainNavigator';
import { RootStackParamList } from './types';
import { useAppSelector } from '../store/hooks';

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function AppNavigator() {
  const token = useAppSelector(state => state.auth.token);

  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      {token ? (
        <Stack.Screen name="Main" component={MainNavigator} />
      ) : (
        <Stack.Screen name="Auth" component={LoginScreen} />
      )}
    </Stack.Navigator>
  );
}
