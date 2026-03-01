import { Stack } from 'expo-router';

export default function RoomsLayout() {
    return (
        <Stack>
            <Stack.Screen name="index" options={{ title: 'Rooms' }} />
            <Stack.Screen name="add" options={{ title: 'Add Room', presentation: 'modal' }} />
            <Stack.Screen name="[id]" options={{ title: 'Room Details' }} />
        </Stack>
    );
}
