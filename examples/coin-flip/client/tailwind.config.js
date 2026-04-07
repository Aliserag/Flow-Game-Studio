/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        'degen-black': '#030303',
        'degen-dark': '#0A0A0A',
        'degen-panel': '#111118',
        'degen-card': '#16161E',
        'neon-green': '#00FF41',
        'neon-red': '#FF2B4E',
        'neon-amber': '#FFB300',
        'neon-blue': '#00BFFF',
        'degen-text': '#E8E8E8',
        'degen-muted': '#4A4A5A',
      },
      fontFamily: {
        'display': ['"Chakra Petch"', 'monospace'],
        'mono': ['"JetBrains Mono"', 'monospace'],
      },
      boxShadow: {
        'neon-green': '0 0 20px rgba(0,255,65,0.4)',
        'neon-red': '0 0 20px rgba(255,43,78,0.4)',
        'neon-amber': '0 0 20px rgba(255,179,0,0.4)',
      },
      animation: {
        'pulse-green': 'pulse-green 2s ease-in-out infinite',
        'pulse-red': 'pulse-red 2s ease-in-out infinite',
        'spin-coin': 'spin-coin 3s forwards',
        'flicker': 'flicker 4s ease-in-out infinite',
        'count-tick': 'count-tick 1s ease-in-out',
      },
      keyframes: {
        'pulse-green': {
          '0%, 100%': { boxShadow: '0 0 10px rgba(0,255,65,0.2)' },
          '50%': { boxShadow: '0 0 30px rgba(0,255,65,0.6)' },
        },
        'pulse-red': {
          '0%, 100%': { boxShadow: '0 0 10px rgba(255,43,78,0.2)' },
          '50%': { boxShadow: '0 0 30px rgba(255,43,78,0.6)' },
        },
        'spin-coin': {
          '0%': { transform: 'rotateY(0deg)' },
          '100%': { transform: 'rotateY(3600deg)' },
        },
        'flicker': {
          '0%, 96%, 100%': { opacity: '1' },
          '97%': { opacity: '0.8' },
          '98%': { opacity: '1' },
          '99%': { opacity: '0.7' },
        },
        'count-tick': {
          '0%': { transform: 'scale(1.1)', color: '#FFB300' },
          '100%': { transform: 'scale(1)', color: '#00FF41' },
        },
      },
    },
  },
  plugins: [],
}
