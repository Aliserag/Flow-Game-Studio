/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        'degen-black': '#06040F',
        'degen-dark': '#0C0818',
        'degen-panel': '#130F24',
        'degen-card': '#1A1535',
        'neon-green': '#00F5FF',
        'neon-red': '#FF0099',
        'neon-amber': '#FFE600',
        'neon-blue': '#7C3AED',
        'degen-text': '#F0EEFF',
        'degen-muted': '#4A3D7A',
      },
      fontFamily: {
        'display': ['"Exo 2"', 'sans-serif'],
        'mono': ['"Fira Code"', 'monospace'],
      },
      boxShadow: {
        'neon-green': '0 0 20px rgba(0,245,255,0.45), 0 0 50px rgba(0,245,255,0.15)',
        'neon-red': '0 0 20px rgba(255,0,153,0.45), 0 0 50px rgba(255,0,153,0.15)',
        'neon-amber': '0 0 20px rgba(255,230,0,0.45)',
      },
      animation: {
        'pulse-green': 'pulse-cyan 2s ease-in-out infinite',
        'pulse-red': 'pulse-magenta 2s ease-in-out infinite',
        'spin-coin': 'spin-coin 3s forwards',
        'flicker': 'flicker 5s ease-in-out infinite',
        'count-tick': 'count-tick 1s ease-in-out',
      },
      keyframes: {
        'pulse-cyan': {
          '0%, 100%': { boxShadow: '0 0 10px rgba(0,245,255,0.2)' },
          '50%': { boxShadow: '0 0 40px rgba(0,245,255,0.7), 0 0 80px rgba(0,245,255,0.3)' },
        },
        'pulse-magenta': {
          '0%, 100%': { boxShadow: '0 0 10px rgba(255,0,153,0.2)' },
          '50%': { boxShadow: '0 0 40px rgba(255,0,153,0.7), 0 0 80px rgba(255,0,153,0.3)' },
        },
        'spin-coin': {
          '0%': { transform: 'rotateY(0deg)' },
          '60%': { filter: 'drop-shadow(0 0 30px rgba(0,245,255,0.9))' },
          '100%': { transform: 'rotateY(3600deg)' },
        },
        'flicker': {
          '0%, 93%, 100%': { opacity: '1' },
          '94%': { opacity: '0.5' },
          '95%': { opacity: '1' },
          '97%': { opacity: '0.3' },
          '98%': { opacity: '1' },
        },
        'count-tick': {
          '0%': { transform: 'scale(1.15)', color: '#FF0099' },
          '100%': { transform: 'scale(1)', color: '#00F5FF' },
        },
      },
    },
  },
  plugins: [],
}
