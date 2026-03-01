import Ionicons from '@expo/vector-icons/Ionicons';
import { Tabs } from 'expo-router';
import React from 'react';

import { useColorScheme } from '@/components/useColorScheme';
import Colors from '@/constants/Colors';

import { TabBarVisibilityProvider, useTabBarVisibility } from './TabBarVisibilityContext';

function TabLayoutContent() {
  const colorScheme = useColorScheme();
  const { hideTabBar } = useTabBarVisibility();

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: Colors[colorScheme].tint,
        tabBarLabelStyle: { fontSize: 14, fontWeight: '700' },
        tabBarStyle: hideTabBar
          ? { display: 'none' }
          : { height: 64, paddingBottom: 8, paddingTop: 8 },
        headerTitleStyle: { fontSize: 22, fontWeight: '700' },
      }}>
      <Tabs.Screen
        name="camera"
        options={{
          title: 'Camera',
          tabBarLabel: 'Camera',
          headerShown: false,
          tabBarIcon: ({ color, size }) => <Ionicons name="camera" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="people"
        options={{
          headerShown: false,
          title: 'People',
          tabBarLabel: 'People',
          tabBarIcon: ({ color, size }) => <Ionicons name="people" size={size} color={color} />,
        }}
      />
      <Tabs.Screen
        name="rooms"
        options={{
          title: 'Rooms',
          tabBarLabel: 'Rooms',
          tabBarIcon: ({ color, size }) => <Ionicons name="book" size={size} color={color} />,
        }}
      />
    </Tabs>
  );
}

export default function TabLayout() {
  return (
    <TabBarVisibilityProvider>
      <TabLayoutContent />
    </TabBarVisibilityProvider>
  );
}
