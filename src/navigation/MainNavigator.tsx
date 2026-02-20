import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StyleSheet } from 'react-native';

import DashboardScreen from '../screens/dashboard/DashboardScreen';
import CheckInScreen from '../screens/checkin/CheckInScreen';
import MembersScreen from '../screens/members/MembersScreen';
import ProfileScreen from '../screens/profile/ProfileScreen';
import MemberDetailScreen from '../screens/members/MemberDetailScreen';
import AddMemberScreen from '../screens/members/AddMemberScreen';
import ImportMemberScreen from '../screens/members/ImportMemberScreen';
import RenewMemberScreen from '../screens/members/RenewMemberScreen';
import { MainTabParamList, MembersStackParamList } from './types';

const Tab = createBottomTabNavigator<MainTabParamList>();
const MembersStack = createNativeStackNavigator<MembersStackParamList>();

function MembersNavigator() {
  return (
    <MembersStack.Navigator
      screenOptions={{
        headerStyle: styles.headerStyle,
        headerTintColor: '#fff',
        headerTitleStyle: styles.headerTitleStyle,
        contentStyle: { backgroundColor: '#111' },
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
        name="ImportMember"
        component={ImportMemberScreen}
        options={{ title: 'Import Member Lama' }}
      />
      <MembersStack.Screen
        name="RenewMember"
        component={RenewMemberScreen}
        options={{ title: 'Perpanjang Membership' }}
      />
    </MembersStack.Navigator>
  );
}

import { LayoutDashboard, QrCode, Users, UserRound } from 'lucide-react-native';

const TAB_ICONS: Record<string, typeof LayoutDashboard> = {
  Dashboard: LayoutDashboard,
  CheckIn: QrCode,
  Members: Users,
  Profile: UserRound,
};

function TabIcon({ name, focused }: { name: string; focused: boolean }) {
  const IconComponent = TAB_ICONS[name];
  return (
    <IconComponent
      size={24}
      color={focused ? '#C8F000' : '#6B7280'}
      strokeWidth={focused ? 2.5 : 2}
    />
  );
}

export default function MainNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        sceneStyle: { backgroundColor: '#111' },
        headerStyle: styles.headerStyle,
        headerTintColor: '#fff',
        headerTitleStyle: styles.headerTitleStyle,
        tabBarStyle: styles.tabBarStyle,
        tabBarActiveTintColor: '#C8F000',
        tabBarInactiveTintColor: '#6B7280',
        tabBarLabelStyle: styles.tabBarLabelStyle,
        tabBarIcon: ({ focused }) => (
          <TabIcon name={route.name} focused={focused} />
        ),
      })}
    >
      <Tab.Screen
        name="Dashboard"
        component={DashboardScreen}
        options={{ title: 'Home' }}
      />
      <Tab.Screen
        name="CheckIn"
        component={CheckInScreen}
        options={{ title: 'Scan', headerShown: false }}
      />
      <Tab.Screen
        name="Members"
        component={MembersNavigator}
        options={{ title: 'Members', headerShown: false }}
      />
      <Tab.Screen
        name="Profile"
        component={ProfileScreen}
        options={{ title: 'Profile', headerShown: false }}
      />
    </Tab.Navigator>
  );
}

const styles = StyleSheet.create({
  headerStyle: {
    backgroundColor: '#111',
    borderBottomWidth: 0,
    elevation: 0,
    shadowOpacity: 0,
  },
  headerTitleStyle: { fontWeight: '800', fontSize: 18, color: '#fff' },
  tabBarStyle: {
    backgroundColor: '#161616',
    borderTopWidth: 1,
    borderTopColor: '#262626',
    height: 68,
    paddingBottom: 10,
    paddingTop: 8,
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -4 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  tabBarLabelStyle: {
    fontSize: 11,
    fontWeight: '600',
    marginTop: -4,
  },
});
