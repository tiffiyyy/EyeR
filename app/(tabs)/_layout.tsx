import React from 'react';
import { Tabs } from 'expo-router';

import Colors from '@/constants/Colors';
import { useColorScheme } from '@/components/useColorScheme';

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
        name="memories"
        options={{
          title: 'Memories',
          tabBarLabel: 'Memories',
        }}
      />
    </Tabs>
  );
}
