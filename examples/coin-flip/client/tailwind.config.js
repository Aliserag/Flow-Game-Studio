/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        'degen-black':   '#05030D',
        'degen-dark':    '#0A0620',
        'degen-panel':   '#100D22',
        'degen-card':    '#16122E',
        'degen-surface': '#1C1838',
        'neon-green':    '#00F5FF',
        'neon-red':      '#FF0099',
        'neon-amber':    '#FFE600',
        'neon-gold':     '#FFD700',
        'neon-blue':     '#7C3AED',
        'cyber-cyan':    '#00FFFF',
        'cyber-pink':    '#FF1493',
        'degen-text':    '#F0EEFF',
        'degen-muted':   '#3D3070',
        'degen-border':  'rgba(0, 245, 255, 0.15)',
      },
      fontFamily: {
        'display': ['"Orbitron"', 'sans-serif'],
        'mono':    ['"Share Tech Mono"', 'monospace'],
      },
      boxShadow: {
        'neon-green':   '0 0 15px rgba(0,245,255,0.5), 0 0 40px rgba(0,245,255,0.2), 0 0 80px rgba(0,245,255,0.1)',
        'neon-red':     '0 0 15px rgba(255,0,153,0.5), 0 0 40px rgba(255,0,153,0.2), 0 0 80px rgba(255,0,153,0.1)',
        'neon-amber':   '0 0 15px rgba(255,230,0,0.5), 0 0 40px rgba(255,230,0,0.2)',
        'neon-gold':    '0 0 15px rgba(255,215,0,0.5), 0 0 40px rgba(255,215,0,0.2)',
        'panel-cyan':   'inset 0 0 60px rgba(0,245,255,0.04), 0 0 30px rgba(0,245,255,0.06)',
        'panel-magenta':'inset 0 0 60px rgba(255,0,153,0.04), 0 0 30px rgba(255,0,153,0.06)',
      },
      animation: {
        'pulse-green':  'pulse-cyan 2.5s ease-in-out infinite',
        'pulse-red':    'pulse-magenta 2.5s ease-in-out infinite',
        'spin-coin':    'spin-coin 3s cubic-bezier(0.25,0.46,0.45,0.94) forwards',
        'flicker':      'flicker 6s ease-in-out infinite',
        'count-tick':   'count-tick 0.3s ease-in-out',
        'coin-float':   'coin-float 3s ease-in-out infinite',
        'glitch':       'glitch-main 0.3s ease-in-out',
        'sweep-in':     'sweep-in 0.5s ease-out forwards',
      },
      keyframes: {
        'pulse-cyan': {
          '0%, 100%': { boxShadow: '0 0 10px rgba(0,245,255,0.2)' },
          '50%':       { boxShadow: '0 0 40px rgba(0,245,255,0.7), 0 0 80px rgba(0,245,255,0.3)' },
        },
        'pulse-magenta': {
          '0%, 100%': { boxShadow: '0 0 10px rgba(255,0,153,0.2)' },
          '50%':       { boxShadow: '0 0 40px rgba(255,0,153,0.7), 0 0 80px rgba(255,0,153,0.3)' },
        },
        'spin-coin': {
          '0%':   { transform: 'rotateY(0deg)' },
          '30%':  { filter: 'drop-shadow(0 0 40px rgba(0,245,255,1)) drop-shadow(0 0 80px rgba(255,0,153,0.6))' },
          '100%': { transform: 'rotateY(3600deg)' },
        },
        'flicker': {
          '0%, 92%, 100%': { opacity: '1' },
          '93%':           { opacity: '0.4' },
          '94%':           { opacity: '1' },
          '96%':           { opacity: '0.2' },
          '97%':           { opacity: '1' },
        },
        'count-tick': {
          '0%':   { transform: 'scale(1.2)', color: '#FF0099' },
          '100%': { transform: 'scale(1)',   color: '#00F5FF' },
        },
        'coin-float': {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%':      { transform: 'translateY(-8px)' },
        },
        'glitch-main': {
          '0%':   { transform: 'translate(0)' },
          '20%':  { transform: 'translate(-3px, 1px)' },
          '40%':  { transform: 'translate(3px, -1px)' },
          '60%':  { transform: 'translate(-2px, 2px)' },
          '80%':  { transform: 'translate(2px, -2px)' },
          '100%': { transform: 'translate(0)' },
        },
        'sweep-in': {
          '0%':   { opacity: '0', transform: 'translateX(-20px)' },
          '100%': { opacity: '1', transform: 'translateX(0)' },
        },
      },
    },
  },
  plugins: [],
}
