s.boot
NetAddr.langPort;


(
b = NetAddr.new("127.0.0.1", 57000);
// Funzione che manda numeri causali che rappresentano il set_order del markov model
~valori = [1, 2, 3, 4, 5, 6, 7, 8];
~close = Routine.new({
    inf.do {
        var chosen = ~valori.choose;
		chosen.postln;
		b.sendMsg("/closeness", chosen);
        1.wait;
    }
}).play;
)


(
SynthDef(\deepBass, {
	arg freq=440, amp=0.2, time=1, detune=5, filterFreq=200;
	var env = EnvGen.ar(Env.new([0, amp, 0], [time/1000, time/200]));

	var sine = SinOsc.ar(freq * (1 + detune/100), 0, 0.5); // Oscillatore a sinusoide con detune
	var sub =LFTri.ar(freq * 0.5, 0, 0.7); // Sottotono a sinusoide
	var sqr=LFPar.ar(freq, 0, 0.5);
	var noise=WhiteNoise.ar(amp)*0.35;
	var filteredSound;

	var sound = sine + sub+sqr + noise;

	sound = FreeVerb.ar(sound, 1, 0.9, 0.5);
	sound = DelayC.ar(sound, 0.2, 0.2, 1);     //Alzando il delay time aumento il feedbakc (modulabile)
	sound = BPeakEQ.ar(sound, 500, 1,0,1);


	//sound = Compander.ar(sound,0,0.5,1,1,0.01,0.1,1 );
	//sound = CombL.ar(sound, 0.2, 0.2, 1,1);
	//sound = CombN.ar(sound, 0.1, 0.1, 4); // Aggiunge riverbero
	//sound = DelayC.ar(sound, 0.5, 0.5, 1);
	filteredSound = LPF.ar(sound, filterFreq);
	//filteredSound = filteredSound * env;

	Out.ar([0, 1], filteredSound * 0.5);
}).add;
)


z = Synth.new(\deepBass);

(
OSCdef.new(\numbers,
	{
		arg msg;
		var freq=msg[1].midicps;
		var amp=  msg[2].linexp(0, 127, 0.5, 1);

		z.set(\freq, freq);
		z.set(\amp, amp);
		postln(msg[1]);
		postln(msg[2]);
	},
	'/numbers',
	nil,
	57120
);
)




(
x = OSCFunc( { |msg, time, addr, recvPort|
    // Estrai i numeri dal messaggio
    var num1 = msg[1].asInteger;
    var num2 = msg[2].asInteger;
    var num3 = msg[3].asInteger;

    // Stampa i numeri nella console
    [num1, num2, num3].postln;
}, '/numbers');
)
s.quit;