import numpy as np
import matplotlib.pyplot as plt
from matplotlib import cm
from mpl_toolkits.mplot3d import Axes3D

x = np.linspace(-2, 1, 751)
y = np.linspace(-1.5, 1.5, 751)
c = x + 1j * y[:, np.newaxis]
X, Y = np.meshgrid(x, y)
z = np.zeros_like(c)
n = np.zeros_like(c)
for i in range(100):
  z = z * z + c
  n += np.abs(z) < 2

fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')
ax.plot_surface(X, Y, n, cmap=cm.coolwarm, linewidth=0, cstride=5, rstride=5)
plt.show()

fig = plt.figure()
ax = fig.add_subplot(111)
ax.contour(X, Y, n)
plt.show()
