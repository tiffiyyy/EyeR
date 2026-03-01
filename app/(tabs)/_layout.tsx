import { Tabs } from 'expo-router';
import React from 'react';

import { useColorScheme } from '@/components/useColorScheme';
import Colors from '@/constants/Colors';

export default function TabLayout() {
  const colorScheme = useColorScheme();

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: Colors[colorScheme].tint,
        tabBarLabelStyle: { fontSize: 14, fontWeight: '700' },
        tabBarStyle: { height: 64, paddingBottom: 8, paddingTop: 8 },
        headerTitleStyle: { fontSize: 22, fontWeight: '700' },
      }}>
      <Tabs.Screen
        name="camera"
        options={{
          title: 'Camera',
          tabBarLabel: 'Camera',
        }}
      />
      <Tabs.Screen
        name="people"
        options={{
          headerShown: false,
          title: 'People',
          tabBarLabel: 'People',
        }}
      />
      <Tabs.Screen
        name="rooms"
        options={{
          headerShown: false,
          title: 'Rooms',
          tabBarLabel: 'Rooms',
        }}
      />
    </Tabs>
  );
}
