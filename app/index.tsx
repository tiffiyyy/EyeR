import { Redirect } from 'expo-router';

// routing so that the camera page shows up when app is opened 
export default function Index() {
  return <Redirect href="/(tabs)/camera" />;
}
