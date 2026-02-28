import { Stack } from "expo-router";

export default function PeopleLayout() {
  return (
    <Stack
      screenOptions={{
        headerTitleStyle: { fontSize: 22, fontWeight: "700" },
      }}
    >
      <Stack.Screen name="index" options={{ title: "People" }} />
      <Stack.Screen name="add" options={{ title: "Add Person" }} />
      <Stack.Screen name="[id]" options={{ title: "Person Details" }} />
    </Stack>
  );
}
