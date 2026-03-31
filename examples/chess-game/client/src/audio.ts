// Chess SFX using Web Audio API — no audio files required

interface SFXParams {
  frequency: number
  duration: number
  type: OscillatorType
  gain: number
  secondFreq?: number
}

class ChessAudio {
  private ctx: AudioContext | null = null
  private muted = false

  private getCtx(): AudioContext {
    if (!this.ctx) {
      this.ctx = new AudioContext()
    }
    return this.ctx
  }

  private playTone(params: SFXParams): void {
    if (this.muted) return
    const ctx = this.getCtx()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    osc.connect(gain)
    gain.connect(ctx.destination)
    osc.type = params.type
    osc.frequency.setValueAtTime(params.frequency, ctx.currentTime)
    if (params.secondFreq) {
      osc.frequency.exponentialRampToValueAtTime(params.secondFreq, ctx.currentTime + params.duration * 0.5)
    }
    gain.gain.setValueAtTime(params.gain, ctx.currentTime)
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + params.duration)
    osc.start(ctx.currentTime)
    osc.stop(ctx.currentTime + params.duration + 0.05)
  }

  playMove(): void {
    this.playTone({ frequency: 220, duration: 0.12, type: 'triangle', gain: 0.3 })
    setTimeout(() => this.playTone({ frequency: 180, duration: 0.08, type: 'triangle', gain: 0.2 }), 40)
  }

  playCapture(): void {
    this.playTone({ frequency: 150, duration: 0.15, type: 'sawtooth', gain: 0.5, secondFreq: 80 })
    this.playTone({ frequency: 300, duration: 0.06, type: 'square', gain: 0.3 })
  }

  playCheck(): void {
    this.playTone({ frequency: 880, duration: 0.4, type: 'sine', gain: 0.4 })
    setTimeout(() => this.playTone({ frequency: 1320, duration: 0.25, type: 'sine', gain: 0.2 }), 60)
  }

  playCheckmate(): void {
    const notes = [523, 659, 784, 1047]
    notes.forEach((freq, i) => {
      setTimeout(() => this.playTone({ frequency: freq, duration: 0.3, type: 'sine', gain: 0.35 }), i * 120)
    })
    setTimeout(() => {
      notes.forEach(freq => this.playTone({ frequency: freq * 2, duration: 0.6, type: 'sine', gain: 0.2 }))
    }, 600)
  }

  setMuted(muted: boolean): void { this.muted = muted }
  isMuted(): boolean { return this.muted }
}

export const chessAudio = new ChessAudio()
