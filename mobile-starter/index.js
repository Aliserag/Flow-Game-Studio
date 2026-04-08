import { registerRootComponent } from 'expo'
import App from './App'

// registerRootComponent calls AppRegistry.registerComponent('main', () => App)
// and wraps App in Expo's root providers. Required for Expo apps.
registerRootComponent(App)
