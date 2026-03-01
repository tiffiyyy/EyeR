// this file stores the routing for the screens on the "people tab"
import { Stack } from "expo-router";

export default function PeopleLayout() {
  return (
    <Stack
      screenOptions={{
        headerTitleStyle: { fontSize: 22, fontWeight: "700" },
      }}
    >
      {/* screen containing all people and "add person" button */}
      <Stack.Screen name="index" options={{ title: "People" }} />
      {/* screen containing form to fill out info to add new person */}
      <Stack.Screen name="add" options={{ title: "Add Person" }} /> 
      {/* screen (can be reached from "index") to see person details once added */}
      <Stack.Screen name="[id]" options={{ title: "Person Details" }} />
    </Stack>
  );
}
