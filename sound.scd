ServerOptions.inDevices;
ServerOptions.outDevices;

(
Server.default.options.memSize=8192*100;
Server.default.options.inDevice_("Gruppo microfoni (Realtek(R) Audio");
s.boot;

// SYNTHS------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SynthDef(\triOsc, {
	arg freq=440, amp=0.1, time=1, detune=25, filterFreq=500;
	var env =EnvGen.ar( Env.new([0,amp, 0], [time/8, time*7/8]), doneAction: Done.freeSelf);
	var sound;
	//var tri=LFTri.ar(freq*(1+detune/100), 0, 0.5);   //OScillatore a onda triangolare con detune
	//var sqr=LFPar.ar(freq, 0, 0.5);            //Oscillatore a onda quadra
	//var noise=WhiteNoise.ar(amp)*0.35;
	//Rumore bianco per la texture
	var filteredSound;
	sound=SinOsc.ar(freq);
	filteredSound=LPF.ar(sound, filterFreq);

	Out.ar(98, filteredSound*env*amp);
}).add;


SynthDef(\paulstretchMono, { |out = 0, bufnum, envBufnum, pan = 0, stretch = 50000, window = 0.5, rate1=0.5, rate2=1.7, rate3=1, rate4=1.5, ampf1=0.1, ampf2=0.09, ampf3=0.8, ampf4=0.7, amp=0.8, gate=0.0, dur=1|

	var trigPeriod, sig, chain, trig, pos, fftSize, env;
	env = Env([0, amp, 0], [dur/8, dur*7/8]);
	fftSize = 2**floor(log2(window*SampleRate.ir));
	trigPeriod = fftSize/SampleRate.ir;
	trig = Impulse.ar(1/trigPeriod);
	pos = Demand.ar(trig, 0, demandUGens: Dseries(0, trigPeriod/stretch));
	sig = [(GrainBuf.ar(1, trig, trigPeriod, bufnum, rate1, pos, envbufnum: envBufnum)), (GrainBuf.ar(1, trig, trigPeriod, bufnum, rate1, pos + (trigPeriod/(2*stretch)), envbufnum: envBufnum))]*amp;
	sig = sig.collect({ |item, i|
		chain = FFT(LocalBuf(fftSize), item, hop: 1.0, wintype: -1);

		chain = PV_Diffuser(chain, 1 - trig);
		item = IFFT(chain, wintype: -1);
	});
	sig = sig*PlayBuf.ar(1, envBufnum, 1/(trigPeriod), loop:1);
	sig[1] = DelayC.ar(sig[1], trigPeriod/2, trigPeriod/2);
	Out.ar(98, Pan2.ar(Mix.new(sig)*EnvGen.kr(env, doneAction: Done.freeSelf), pan));
	Out.ar(80, Pan2.ar(Mix.new(sig)*EnvGen.kr(env, doneAction: Done.freeSelf), pan));
}).add;

{
	var envBuf, envSignal, buffer;
	~buffer = Buffer.readChannel(s, thisProcess.nowExecutingPath.dirname +/+ "string1.wav");
	// The grain envelope
	~envBuf = Buffer.alloc(s, s.sampleRate, 1);
	envSignal = Signal.newClear(s.sampleRate).waveFill({|x| (1 - x.pow(2)).pow(1)}, -1.0, 1.0);
	~envBuf.loadCollection(envSignal);
	s.sync();
}.fork;







// EFFECTS -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SynthDef(\clean, {
	arg amp=1, freq=100, wet=1;
	var in;
	in=In.ar(98, 2);
	in=FreeVerb2.ar(in[0], in[1], wet, 1, 0.8);
	in=HPF.ar(in, freq: 300);
	in=LPF.ar(in, freq: freq);
	Out.ar([0,1], in*amp);
}).add;

SynthDef(\shimmerwet, {
	arg amp=0.1, cutoff=1200;
	var in;
	in=In.ar(94, 2);
	3.do{in=in.distort;
	in=FreeVerb2.ar(in[0], in[1], 0.93, 1, 0.8);
	//in=HPF.ar(in, freq: 1500.0);
	in=LPF.ar(in, freq: cutoff);};
	Out.ar(0, in*amp);
}).add;

SynthDef(\reverb, {
	arg in = 80,
		processMode = 0, // 0 uses Control values, 1 uses Bus for any param suffix Bus.
		gain = 0, mix = 1,
		processGain = 0, processGainBus = 99,
		preDelay = 0.001, bandwidth = 0.998,
		decayRate = 0.97, decayRateBus = 99,
		tailDensity = 0.7, damping = 0.0005,
		excursionDepth = 0.2, excursionRate = 5,
		shimmerPitch = 4, shimmerPitchBus = 99,
	    amp2=0,
		out = 94;

	// funcs
	var sampleRate		= Server.default.sampleRate;
	var equalPower        = {
		arg mix = 0.5;
		[(1-mix).sqrt, mix.sqrt];
	};
	var sampSec           = {
		arg numSamp, sampRate;
		numSamp / sampRate;
	};

	var gFacT60           = {
		arg delay, gFac;
		gFac.sign * (-3 * delay / log10(gFac.abs));

	};
	// some constant values
	// dSR = datorroSampleRate, sampleRate used in the paper.
	var dSR = 29761;
	var maxExcursion    = 32; // samples

	// values for prep part
	var preTankVals = [
		[0.75, 0.75, 0.625, 0.625], // gFacs
		sampSec.value([142, 107, 379, 277], dSR) // times
	].flop;

	// values for tank part
	// note that Dattorro flipped the sign of gFacs for the decaying APs,
	// I do that here so I don't worry about the signs later.
	var tankAP1GFac = -1 * tailDensity;
	var tankAP1Time = 672;
	var tankDel1    = sampSec.value(4453, dSR);
	var tankAP2GFac = (decayRate + 0.15).min(0.5).max(0.25);
	var tankAP2Time = sampSec.value(1800, dSR);
	var tankDel2    = sampSec.value(3720, dSR);

	var tankAP3GFac = tankAP1GFac;
	var tankAP3Time = 908;
	var tankDel3    = sampSec.value(4217, dSR);
	var tankAP4GFac = tankAP2GFac;
	var tankAP4Time = sampSec.value(2656, dSR);
	var tankDel4    = sampSec.value(3163, dSR);

	// Signals
	var dry     = In.ar(in, 2);
	var preTank = Silent.ar;
	var tank    = Silent.ar;
	var wetL    = Silent.ar;
	var wetR    = Silent.ar;
	var wet     = Silent.ar;
	var outs    = Silent.ar;

	// Params
	var pGain = Select.kr(processMode, [processGain.dbamp, Lag.kr(In.kr(processGainBus), 0.05)]);
	var sPitch = Select.kr(processMode, [shimmerPitch, Lag.kr(In.kr(shimmerPitchBus), 0.05)]);

	var fback;

	var dryAmp, wetAmp;
	#dryAmp, wetAmp = equalPower.value(mix);

	// proper mappings for params
	damping = (damping + (1 + (8 * damping))).log / (10.log); // somewhat better than linear
	bandwidth = 3.pow(bandwidth) - (1 + bandwidth);


	// ROUTINGS
	// make it mono
	preTank = (dry[0] + dry[1]) / 2;
	// pregain
	preTank = preTank * pGain;
	// predelay
	preTank = DelayC.ar(preTank, preDelay, preDelay);
	// lowpass
	preTank = LPF.ar(preTank, sampleRate / 2 * bandwidth);

	// 4 All-passes to diffuse inputs
	preTankVals.do({ arg pair; // 0: gFac, 1: time
		preTank = AllpassC.ar(preTank, pair[1], pair[1], gFacT60.value(pair[1], pair[0]));
	});

	fback = LocalIn.ar(1);

	// // Tank starts here
	// first branch
	tank  = AllpassC.ar(preTank + (decayRate * fback),
		maxdelaytime: sampSec.value(tankAP1Time + maxExcursion, dSR),
		delaytime: sampSec.value(tankAP1Time, dSR)
		+ (sampSec.value(maxExcursion, dSR) * excursionDepth * SinOsc.ar(excursionRate)),
		decaytime: gFacT60.value(sampSec.value(tankAP1Time, dSR), tankAP1GFac)
	);

	     wetL = -0.6 * DelayC.ar(tank, sampSec.value(1990, dSR), sampSec.value(1990, dSR)) + wetL;
	     wetR = 0.6 * tank + wetR;
	     wetR = 0.6 * DelayC.ar(tank, sampSec.value(3300, dSR), sampSec.value(3300, dSR)) + wetR;
	tank = DelayC.ar(tank, tankDel1, tankDel1);
	tank = LPF.ar(tank, sampleRate / 2 * (1 - damping)) * decayRate;
	     wetL = -0.6 * tank + wetL;
	tank = AllpassC.ar(tank, tankAP2Time, tankAP2Time, gFacT60.value(tankAP2Time, tankAP2GFac));
	     wetR = -0.6 * tank + wetR;
	tank = DelayC.ar(tank, tankDel2, tankDel2);
	     wetR = 0.6 * tank + wetR;

	// // second branch
	tank  = AllpassC.ar((tank * decayRate) + preTank,
		maxdelaytime: sampSec.value(tankAP3Time + maxExcursion, dSR),
		delaytime: sampSec.value(tankAP3Time, dSR)
		+ (sampSec.value(maxExcursion, dSR) * excursionDepth * 0.8 * SinOsc.ar(excursionRate * 0.8)),
		decaytime: gFacT60.value(sampSec.value(tankAP3Time, dSR), tankAP3GFac)
	);

	     wetL = 0.6 * tank + wetL;
	     wetL = 0.6 * DelayC.ar(tank, sampSec.value(2700, dSR), sampSec.value(2700, dSR)) + wetL;
	     wetR = -0.6 * DelayC.ar(tank, sampSec.value(2100, dSR), sampSec.value(2100, dSR)) + wetR;
	tank = DelayC.ar(tank, tankDel3, tankDel3);
	tank = LPF.ar(tank, sampleRate / 2 * (1 - damping)) * decayRate;
	tank = AllpassC.ar(tank, tankAP4Time, tankAP4Time, gFacT60.value(tankAP4Time, tankAP4GFac));
	     wetL = -0.6 * tank + wetL;
	     wetR = -0.6 * DelayC.ar(tank, sampSec.value(200, dSR), sampSec.value(200, dSR)) + wetR;

	tank = DelayC.ar(tank, tankDel4, tankDel4);
	     wetL = 0.6 * tank + wetL;

	tank = tank * decayRate;
	// // Sloppy Shimmering
	tank = PitchShift.ar(tank, pitchRatio: sPitch, mul: Select.kr(sPitch > 1, [1, 2.dbamp]));
	// // Tank ends here
	LocalOut.ar(tank);

    wet = [wetL, wetR];
	wet = HPF.ar(wet, 40); // Prevent lows from blowing up.

	outs = (dry * dryAmp) + (wet * wetAmp);
	outs = outs * gain.dbamp;

	Out.ar(out, outs);
	Out.ar(0, outs*amp2);
}).add;

a=Synth.new(\clean);
y=Synth.new(\shimmerwet);
z=Synth.new(\reverb);








// COMMUNICATION------------------------------------------------------------------------------------------------------------------------------------------------------------------

OSCdef.new(\0,
	{
		arg msg;
		postln(msg);
		x=Synth.new(\paulstretchMono, [\bufnum, ~buffer.bufnum, \envBufnum, ~envBuf.bufnum, \rate1, 2**((msg[1]-24)/12), \dur, msg[4], \amp, msg[2].linexp(0, 127, 0.5, 1)]);
		k=Synth.new(\triOsc, [\freq, (msg[1]+12).midicps, \time, msg[4], \amp, msg[2].linexp(0, 127, 0.2, 1.5)]);
		//{BPF.ar(WhiteNoise.ar, [msg[1]-12, msg[1]-12 ].midicps, 1e-5, Env.sine(2*msg[4]).kr(msg[2])).sum!2}.play;
	},
	'/numbers',
	nil,
	57120
);

OSCdef.new(\chan1,
	{
		arg msg;
		postln(msg);
		a.set(\amp, msg[1].linlin(0, 1, 0, 1), \wet, msg[1].linlin(0, 1, 1, 0.2), \freq, msg[1].linexp(0, 1, 500, 600));
		y.set(\amp, msg[1].linlin(0, 1, 0.1, 0.00000000000000001));
		z.set(\amp2, msg[1].linlin(0, 1, 0.001, 0.0000000000000000000000001));
	},
	'/chan1',
	nil,
	10000
);

)
