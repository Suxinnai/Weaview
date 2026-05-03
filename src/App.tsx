/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { ThemeProvider } from './components/ThemeProvider';
import { Chat } from './components/Chat';
import { PhoneSimulator } from './components/PhoneSimulator';

export default function App() {
  return (
    <ThemeProvider>
      <PhoneSimulator>
        <Chat />
      </PhoneSimulator>
    </ThemeProvider>
  );
}
