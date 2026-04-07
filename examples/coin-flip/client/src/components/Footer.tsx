const Footer = () => (
  <footer className="mt-8 border-t border-neon-green/10">
    <div className="bg-degen-dark py-3 text-center">
      <p className="font-display text-xs tracking-[0.3em] text-degen-muted uppercase">
        PROVABLY FAIR /{' '}
        <a
          href="https://developers.flow.com/build/advanced-concepts/randomness"
          className="text-neon-green hover:text-neon-green/70 transition-colors underline underline-offset-2"
          target="_blank"
          rel="noopener noreferrer"
        >
          LEARN MORE
        </a>
      </p>
    </div>
    <p className="font-mono text-xs text-degen-muted text-center py-4 px-4">
      Made for the degen community by the degen community /{' '}
      <a
        href="https://contractbrowser.com/A.323e80d6db9b41db.CoinFlip"
        className="text-neon-green hover:text-neon-green/70 underline underline-offset-2 transition-colors font-bold"
      >
        contact
      </a>
    </p>
  </footer>
)

export default Footer
