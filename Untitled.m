   %% Time specifications:
   Fs = 5000;                      % samples per second
   dt = 1/Fs;                     % seconds per sample


   %% Sine wave:
                          % hertz
   x = importdata('D:\Users\Zafeiropoulos7780\MatlabFiles\ecg_1.txt');

   %% Fourier Transform:
   X = fftshift(fft(x));

   %% Frequency specifications:
   dF = Fs/N;                      % hertz
   f = -Fs/2:dF:Fs/2-dF;           % hertz

   %% Plot the spectrum:
   figure;
   plot(f,abs(X)/N);
   xlabel('Frequency (in hertz)');
   title('Magnitude Response');