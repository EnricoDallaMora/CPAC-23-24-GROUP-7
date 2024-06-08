
import numpy as np
from sklearn.preprocessing import QuantileTransformer
from scipy.stats import norm

def transform_and_quantize(values, N):
    # Reshape values for QuantileTransformer
    values = np.array(values).reshape(-1, 1)
    
    # Quantile transformation to uniform distribution
    qt = QuantileTransformer(n_quantiles=min(len(values), 100), output_distribution='uniform')
    uniform_values = qt.fit_transform(values)
    
    # Transform uniform distribution to Gaussian distribution
    gaussian_values = norm.ppf(uniform_values)
    
    # Define quantization levels directly over a standard Gaussian range
    quantization_levels = np.linspace(-3, 3, N)
    
    # Quantize the Gaussian-distributed values
    quantized_indices = np.digitize(gaussian_values, quantization_levels, right=True) - 1
    quantized_indices = np.clip(quantized_indices, 0, N-1)
    
    return quantized_indices, qt

def inverse_transform(quantized_indices, qt, N):
    # Define quantization levels directly over a standard Gaussian range
    quantization_levels = np.linspace(-3, 3, N)
    
    # Get the Gaussian values from quantized indices
    gaussian_values = quantization_levels[quantized_indices]
    
    # Transform Gaussian values back to uniform distribution
    uniform_values = norm.cdf(gaussian_values)
    
    # Inverse transform uniform distribution back to original values
    original_values = qt.inverse_transform(uniform_values.reshape(-1, 1))
    
    return original_values.ravel()

# Example usage:
values = [2.3, 1.5, 3.7, 2.1, 5.4, 3.3, 4.4, 2.9, 1.1, 3.9, 2.3, 1.5, 3.7, 2.1, 5.4, 3.3, 4.4, 2.9, 1.1, 3.9]
N = 5  # Number of quantization levels

# Transform and quantize
quantized_indices, qt = transform_and_quantize(values, N)

# Inverse transform to original values
reconstructed_values = inverse_transform(quantized_indices, qt, N)
print("\n")
print("Original values:", values)
print("\n")
print("Quantized indices:", quantized_indices)
print("\n")
print(qt)
print("\n")
print("Reconstructed values:", reconstructed_values)
print("\n")
