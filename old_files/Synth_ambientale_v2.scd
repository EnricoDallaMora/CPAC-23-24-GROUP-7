s.boot
s.queryAllNodes
Server.killAll;


//FISSATO
(
SynthDef(\triOsc, {
	arg freq=440, amp=0.1, time=1, detune=25, filterFreq=1000;
	var env =EnvGen.ar( Env.new([0,amp, 0], [time/1000, time/200]));
	var sound;
	var tri=LFTri.ar(freq*(1+detune/100), 0, 0.5);   //OScillatore a onda triangolare con detune
	var sqr=LFPar.ar(freq, 0, 0.5);            //Oscillatore a onda quadra
	var noise=WhiteNoise.ar(amp)*0.35;                    //Rumore bianco per la texture
	var filteredSound;


	sound=tri+sqr+noise;

	sound=FreeVerb.ar(sound, 1, 0.9,0.5);
	//sound = CombN.ar(sound, 0.1, 0.1, 4); // Aggiunge riverbero
	//sound=DelayC.ar(sound, 0.5, 0.5, 1);
	filteredSound=LPF.ar(sound, filterFreq);
	//filteredSound= filteredSound* env;


	Out.ar([0,1], filteredSound*0.1);
}).add)



Synth.new(\triOsc);



//FISSATO
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

Synth.new(\deepBass);



//FISSATO
(
SynthDef(\orientalSound, {
    arg freq=440, amp=0.5, detune=10, filterFreq=800, pan=0;

    // Oscillatori
    var sine = SinOsc.ar(freq * [1, 1.01].midiratio, 0, amp); // Oscillatori sinusoidali con leggero detuning
    var saw = Saw.ar(freq * 0.5, 0, amp * 0.5); // Onda quadra con frequenza dimezzata

    // Filtro
    var filteredSound = LPF.ar(sine + saw, filterFreq);

    // Output del suono
    Out.ar([0, 1], Pan2.ar(filteredSound, pan));
}).add;
)
Synth.new(\orientalSound);







(
SynthDef(\deepAmbient, {
	arg freq=110, amp=0.4, time=4, detune=10, filterFreq=300, pan=0;
	var env = EnvGen.kr(Env.perc(0.01, time), doneAction: 2);

	var sine = SinOsc.ar(freq * (1 + detune/100), 0, 0.5); // Oscillatore a sinusoide con detune
	var sub = Saw.ar(freq * 0.5, 0, 0.7); // Sottotono a sega

	var sound = Mix([sine, sub]);

	sound = FreeVerb.ar(sound, 1, 0.9, 0.5);
	//sound = DelayC.ar(sound, 0.5, 0.5, 1);
	sound = LPF.ar(sound, filterFreq);

	Out.ar([0, 1], Pan2.ar(sound, pan));
}).add;
)

Synth.new(\deepAmbient);

(
SynthDef(\complexDeepAmbient, {
	arg amp=0.5, detune=10, filterFreq=500, pan=0;
	var env = EnvGen.kr(Env.perc(0.01, 4), doneAction: 2);

	var sine1 = SinOsc.ar(440 * (1 + detune/100), 0, amp); // Primo oscillatore a sinusoide con detune
	var sine2 = SinOsc.ar(440 * (1 - detune/100) * 1.01, 0, amp * 0.7); // Secondo oscillatore a sinusoide leggermente detunato
	var saw = Saw.ar(440 * 0.5, 0, 0.1); // Oscillatore a sega
	var square = LFPulse.ar(440, 0, 0.3); // Oscillatore a onda quadra
	var noise = PinkNoise.ar(amp * 0.2); // Rumore rosa per texture

	var sound = Mix([sine1, sine2, saw, square, noise]);

	sound = FreeVerb.ar(sound, 1, 0.9, 0.5);
	//sound = DelayC.ar(sound, 0.5, 0.5, 1);
	sound = LPF.ar(sound, filterFreq);

	Out.ar([0, 1], Pan2.ar(sound, pan));
}).add;
)

Synth.new(\complexDeepAmbient);



(
SynthDef(\deepSound, {
	arg freq=110, amp=0.6, detune=5, filterFreq=400, pan=0;
	var env = EnvGen.kr(Env.perc(0.01, 3), doneAction: 2);

	var square = LFPulse.ar(freq * (1 + detune/100), 0, amp * 0.7); // Onda quadra con detune
	var triangle = LFTri.ar(freq * (1 - detune/100), 0, amp * 0.5); // Onda triangolare con detune

	var sound = Mix([square, triangle]);

	sound = FreeVerb.ar(sound, 1, 0.9, 0.5); // Aggiunge riverbero
	sound = LPF.ar(sound, filterFreq); // Filtra il suono

	Out.ar([0, 1], Pan2.ar(sound, pan)); // Panning stereo
}).add;
)

Synth.new(\deepSound);



(
SynthDef(\relaxingSound, {
	arg freq=440, amp=0.5, time=2, detune=10, filterFreq=200;
	var env =EnvGen.ar( Env.new([0,amp, 0], [time/1000, time/200]));

	var sine1 = SinOsc.ar(freq * (1 + detune/100), 0, 0.5); // Onda sinusoidale con detune
	var sine2 = SinOsc.ar(freq * (1 - detune/100) * 1.01, 0, 0.5); // Onda sinusoidale leggermente detunata
	var filteredSound;

	var sound = Mix([sine1, sine2]);

	sound = FreeVerb.ar(sound, 1, 0.7, 0.3); // Aggiunge riverbero
	filteredSound = LPF.ar(sound, filterFreq); // Filtra il suono

	Out.ar([0, 1], filteredSound);
}).add;
)

Synth.new(\relaxingSound);

(
SynthDef(\relaxingSquareTriangle, {
	arg freq=880, amp=0.2, time=2, detune=0, filterFreq=400, pan=0;
	var env =EnvGen.ar( Env.new([0,amp, 0], [time/1000, time/200]));

	var square = LFPulse.ar(freq * (1 + detune/100), 0, 0.7); // Onda quadra con detune
	var triangle = LFTri.ar(freq * (1 - detune/100) * 1.005, 0, 0.5); // Onda triangolare leggermente detunata
	var filteredSound;

	var sound = Mix([square, triangle]);

	sound = FreeVerb.ar(sound, 1, 0.7, 0.3); // Aggiunge riverbero
	sound = LPF.ar(sound, filterFreq); // Filtra il suono

	Out.ar([0, 1], Pan2.ar(sound, pan)); // Panning stereo
}).add;
)

Synth.new(\relaxingSquareTriangle);









(
SynthDef("waveguideFlute", { arg scl = 0.2, freq = 440, ipress = 0.9, ibreath = 0.09, ifeedbk1 = 0.4, ifeedbk2 = 0.4, dur = 1, gate = 1, amp = 2, time=1;

	var kenv1, kenv2, kenvibr, kvibr, sr, cr, block;
	var poly, signalOut, ifqc;
	var aflow1, asum1, asum2, afqc, atemp1, ax, apoly, asum3, avalue, atemp2, aflute1;
	var fdbckArray;

	sr = SampleRate.ir;
	cr = ControlRate.ir;
	block = cr.reciprocal;

	ifqc = freq;

	// noise envelope
	kenv1 = EnvGen.kr(Env.new(
		[ 0.0, 1.1 * ipress, ipress, ipress, 0.0 ], [ 0.06, 0.2, dur - 0.46, 0.2 ], 'linear' )
	);
	// overall envelope
	kenv2 = EnvGen.kr(Env.new(
		[ 0.0, amp, amp, 0.0 ], [ 0.1, dur - 0.02, 0.1 ], 'linear' ), doneAction: 1
	);
	// vibrato envelope
	kenvibr = EnvGen.kr(Env.new( [ 0.0, 0.0, 1, 1, 0.0 ], [ 0.5, 0.5, dur - 1.5, 0.5 ], 'linear') );

	// create air flow and vibrato
	aflow1 = LFClipNoise.ar( sr, kenv1 );
	kvibr = SinOsc.ar( 5, 0, 0.1 * kenvibr );

	asum1 = ( ibreath * aflow1 ) + kenv1 + kvibr;
	afqc = ifqc.reciprocal - ( asum1/20000 ) - ( 9/sr ) + ( ifqc/12000000 ) - block;

	fdbckArray = LocalIn.ar( 1 );

	aflute1 = fdbckArray;
	asum2 = asum1 + ( aflute1 * ifeedbk1 );

	//ax = DelayL.ar( asum2, ifqc.reciprocal * 0.5, afqc * 0.5 );
	ax = DelayC.ar( asum2, ifqc.reciprocal - block * 0.5, afqc * 0.5 - ( asum1/ifqc/cr ) + 0.001 );

	apoly = ax - ( ax.cubed );
	asum3 = apoly + ( aflute1 * ifeedbk2 );
	avalue = LPF.ar( asum3, 2000 );

	aflute1 = DelayC.ar( avalue, ifqc.reciprocal - block, afqc );

	fdbckArray = [ aflute1 ];

	LocalOut.ar( fdbckArray );

	signalOut = avalue;

	OffsetOut.ar( 0, [ signalOut * kenv2, signalOut * kenv2 ] );

}).add;
)



Synth.new(\waveguideFlute);




(OSCdef.new(\mix,
	{
		arg msg;
		var freq=msg[2].midicps;
		var amp=  msg[3].linexp(0, 127, 0.5, 1);
		var time=  3*msg[4];

		var x=Synth.new(\triOsc, [\freq,freq, \amp, amp, \time, time]);
		var y=Synth.new(\sampleHold, [\flutefreq, freq, \amp, amp, \time, time]);
		postln('');
		postln(msg[1]);
		postln(msg[2]);
		postln(msg[3]);
		postln(msg[4]);
	},
	'/mix',
	nil,
	7001
);
)