import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
from itertools import product
cmap = mpl.colormaps['tab10']

from utils import get_spowl_logs, plot_metric
plt.style.use('ggplot')


def plot():
    tasks = ['rae 5ens5 avg', 're', 'ccel thr 1', 'ccel thr 0.1', 'ccel thr 0.01']
    labels = ['SPOWL', 'adaptive', '1', '0.1', '0.01']
    colors = [cmap(4), cmap(0), cmap(1), cmap(2), cmap(3)]
    metrics = [
        ('eval/mean_reward_return', 'Reward'),
        ('eval/mean_cost_return', 'Cost'),
        ('train/cost_rate', 'Cost Rate'),
    ]
    
    rows, cols = 2, 3
    fig, ax = plt.subplots(rows, cols, figsize=(8, 5), layout='constrained')
    
    ax[0][0].set_title('Return')
    ax[0][1].set_title('Costs')
    ax[0][2].set_title('Cost Rate')
    
    ax[0][0].set_ylim(-3, 30)
    ax[1][0].set_ylim(-3, 25)
    for i in range(2):
        ax[i][1].set_ylim(0, 150)
    ax[0][2].set_ylim(0, 0.1)
    ax[i][2].set_ylim(0, 0.2)
    
    for i in range(rows):
        for j in range(cols):
            ax[i][j].grid(color='lightgrey')
            ax[i][j].set_facecolor("white")

    for i in range(cols):
        ax[rows-1][i].set_xlabel(r'Env Steps (x $10^6$)')

    # MAIN PLOT
    ax[0][0].set_ylabel('Local')
    tasks1 = [f'PG1 {n}' for n in tasks]
    lines = []
    for i, task in enumerate(tasks1):
        data = get_spowl_logs(task, metrics)
        lines.append(plot_metric(data['steps'], data['Reward'], ax[0][0], colors[i]))
        plot_metric(data['steps'], data['Cost'], ax[0][1], colors[i])
        plot_metric(data['steps'], data['Cost Rate'], ax[0][2], colors[i])
        
    ax[1][0].set_ylabel('Local')
    tasks2 = [f'PG2 {n}' for n in tasks]
    for i, task in enumerate(tasks2):
        data = get_spowl_logs(task, metrics)
        plot_metric(data['steps'], data['Reward'], ax[1][0], colors[i])
        plot_metric(data['steps'], data['Cost'], ax[1][1], colors[i])
        plot_metric(data['steps'], data['Cost Rate'], ax[1][2], colors[i])
    # END MAIN PLOT

    fig.legend(lines, labels, ncols=5, loc='outside lower center')
    for i, j in product(range(rows), range(cols)):
        ax[i][j].set_xticks(np.arange(6) * 1e6)
        ax[i][j].set_xticklabels(['', '1', '2', '3', '4', '5'])
        ax[i][j].set_xlim(0, 5_000_000)

    plt.savefig('results.png', dpi=800)
    plt.close('all')


plot()