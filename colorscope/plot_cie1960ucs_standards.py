"""
Tried to plot several standards overlayed on CIE colorspace diagrams.

Can only get 1960 version to somewhat look proper.

Also would like color temperature curve. And perhaps color classification by
CIE UCS area.
"""

from colour import RGB_COLOURSPACES, xy_to_UCS_uv
import matplotlib.pyplot as plt
import numpy as np
from scipy.spatial import ConvexHull


def plot_cie19xx_ucs_with_standards(year, filename, monitor_gamut='sRGB',
                                natural_colors=True):

    if len(str(year)) == 2:
        year = '19'+str(year)

    # Initialize CIE UCS plot
    #if str(year) == '1931':
    #    plot_chromaticity_diagram_CIE1931(standalone=False)
    if str(year) == '1960':
        from colour.plotting import plot_chromaticity_diagram_CIE1960UCS
        plot_chromaticity_diagram_CIE1960UCS(show=False)
    elif str(year) == '1976':
        from colour.plotting import plot_chromaticity_diagram_CIE1976UCS
        plot_chromaticity_diagram_CIE1976UCS(show=False)
    else:
        raise Error("Not a CIE standard year: %s" % year)

    # Color spaces to plot
    standards = [
            'NTSC (1953)',
            'Adobe RGB (1998)',
            'DCI-P3',
            'ITU-R BT.2020',
            'sRGB']
    colors = ['r', 'g', 'b', 'm', 'y']  # Colors for each gamut boundary

    # Plot each color space gamut
    for cs_name, color in zip(standards, colors):
        cs = RGB_COLOURSPACES[cs_name]
        # Get primaries (RGB) in CIE 1931 xy
        primaries_xy = cs.primaries  # [[Rx, Ry], [Gx, Gy], [Bx, By]]
        # Convert to CIE 1960 u', v'
        primaries_uv = [xy_to_UCS_uv(xy) for xy in primaries_xy]
        # Close the triangle
        primaries_uv = np.vstack([primaries_uv, primaries_uv[0]])
        u, v = primaries_uv[:, 0], primaries_uv[:, 1]
        plt.plot(u, v, color=color, label=cs_name, linewidth=1)

    # Plot monitor gamut (sRGB as proxy, replace with ICC primaries if avail)
    monitor_cs = RGB_COLOURSPACES[monitor_gamut]
    monitor_xy = monitor_cs.primaries
    monitor_uv = [xy_to_UCS_uv(xy) for xy in monitor_xy]
    monitor_uv = np.vstack([monitor_uv, monitor_uv[0]])
    u, v = monitor_uv[:, 0], monitor_uv[:, 1]
    plt.fill(u, v, color='gray', alpha=0.5, label='Monitor (sRGB)')

    # Plot natural colors (approximate Pointer's Gamut)
    if natural_colors:
        # Approximate Pointer's Gamut (simplified, real data requires dataset)
        pointer_xy = np.array([
            [0.35, 0.35], [0.40, 0.45], [0.30, 0.50], [0.20, 0.40],
            [0.25, 0.30], [0.35, 0.25], [0.45, 0.30], [0.50, 0.40]
        ])  # Example points
        pointer_uv = [xy_to_UCS_uv(xy) for xy in pointer_xy]
        hull = ConvexHull(pointer_uv)
        hull_uv = np.array(pointer_uv)[hull.vertices]
        hull_uv = np.vstack([hull_uv, hull_uv[0]])
        u, v = hull_uv[:, 0], hull_uv[:, 1]
        plt.fill(u, v, color='orange', alpha=0.3, label='Natural Colors')

    # Customize plot
    plt.legend(loc='upper right')
    plt.title('CIE %s UCS with Color Spaces and Natural Colors' % year)
    plt.savefig(filename, format='png', bbox_inches='tight')
    plt.close()

# Example usage
plot_cie19xx_ucs_with_standards(60, 'cie1960ucs_standards.png')
plot_cie19xx_ucs_with_standards(76, 'cie1976ucs_standards.png')
