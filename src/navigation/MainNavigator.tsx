import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StyleSheet, Text } from 'react-native';

import DashboardScreen from '../screens/dashboard/DashboardScreen';
import CheckInScreen from '../screens/checkin/CheckInScreen';
import MembersScreen from '../screens/members/MembersScreen';
import MemberDetailScreen from '../screens/members/MemberDetailScreen';
import AddMemberScreen from '../screens/members/AddMemberScreen';
import RenewMemberScreen from '../screens/members/RenewMemberScreen';
import { MainTabParamList, MembersStackParamList } from './types';

const Tab = createBottomTabNavigator<MainTabParamList>();
const MembersStack = createNativeStackNavigator<MembersStackParamList>();

function MembersNavigator() {
  return (
    <MembersStack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: '#1E1E1E' },
        headerTintColor: '#fff',
        headerTitleStyle: { fontWeight: 'bold' },
      }}
    >
      <MembersStack.Screen
        name="MembersList"
        component={MembersScreen}
        options={{ title: 'Members' }}
      />
      <MembersStack.Screen
        name="MemberDetail"
        component={MemberDetailScreen}
        options={{ title: 'Detail Member' }}
      />
      <MembersStack.Screen
        name="AddMember"
        component={AddMemberScreen}
        options={{ title: 'Tambah Member' }}
      />
      <MembersStack.Screen
        name="RenewMember"
        component={RenewMemberScreen}
        options={{ title: 'Perpanjang Membership' }}
      />
    </MembersStack.Navigator>
  );
}

const TAB_ICON: Record<string, string> = {
  Dashboard: '📊',
  CheckIn: '✅',
  Members: '👥',
};

function TabIcon({ name, focused }: { name: string; focused: boolean }) {
  return (
    <Text style={focused ? styles.tabIconFocused : styles.tabIconUnfocused}>
      {TAB_ICON[name]}
    </Text>
  );
}

export default function MainNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerStyle: { backgroundColor: '#1E1E1E' },
        headerTintColor: '#fff',
        headerTitleStyle: { fontWeight: 'bold' },
        tabBarStyle: {
          backgroundColor: '#1E1E1E',
          borderTopColor: '#333',
          height: 64,
          paddingBottom: 8,
        },
        tabBarActiveTintColor: '#C8F000',
        tabBarInactiveTintColor: '#6B7280',
        tabBarIcon: ({ focused }) => (
          <TabIcon name={route.name} focused={focused} />
        ),
      })}
    >
      <Tab.Screen
        name="Dashboard"
        component={DashboardScreen}
        options={{ title: 'Dashboard' }}
      />
      <Tab.Screen
        name="CheckIn"
        component={CheckInScreen}
        options={{ title: 'Check-in', headerShown: false }}
      />
      <Tab.Screen
        name="Members"
        component={MembersNavigator}
        options={{ title: 'Members', headerShown: false }}
      />
    </Tab.Navigator>
  );
}

const styles = StyleSheet.create({
  tabIconFocused: { fontSize: 22, opacity: 1 },
  tabIconUnfocused: { fontSize: 22, opacity: 0.5 },
});
