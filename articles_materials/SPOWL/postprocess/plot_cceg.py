import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
from itertools import product
cmap = mpl.colormaps['tab10']

from utils import get_spowl_logs, plot_metric
plt.style.use('ggplot')


def plot_cceg():
    tasks = ['cceg thr 1', 'cceg thr 3', 'cceg thr 5', 'cceg thr 10', 'cceg thr 25', 'rae 5ens5 avg', 're']
    labels = ['1', '3', '5', '10', '25', 'SPOWL', 'adaptive']
    colors = [cmap(1), cmap(2), cmap(3), cmap(5), cmap(6), cmap(4), cmap(0)]
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
    ax[0][0].set_ylabel('Global')
    tasks1 = [f'PG1 {n}' for n in tasks]
    lines = []
    for i, task in enumerate(tasks1):
        data = get_spowl_logs(task, metrics)
        lines.append(plot_metric(data['steps'], data['Reward'], ax[0][0], colors[i]))
        plot_metric(data['steps'], data['Cost'], ax[0][1], colors[i])
        plot_metric(data['steps'], data['Cost Rate'], ax[0][2], colors[i])
        
    ax[1][0].set_ylabel('Global')
    tasks2 = [f'PG2 {n}' for n in tasks]
    for i, task in enumerate(tasks2):
        data = get_spowl_logs(task, metrics)
        plot_metric(data['steps'], data['Reward'], ax[1][0], colors[i])
        plot_metric(data['steps'], data['Cost'], ax[1][1], colors[i])
        plot_metric(data['steps'], data['Cost Rate'], ax[1][2], colors[i])
    # END MAIN PLOT

    fig.legend(lines, labels, ncols=7, loc='outside lower center')
    for i, j in product(range(rows), range(cols)):
        ax[i][j].set_xticks(np.arange(6) * 1e6)
        ax[i][j].set_xticklabels(['', '1', '2', '3', '4', '5'])
        ax[i][j].set_xlim(0, 5_000_000)

    plt.savefig('results.png', dpi=800)
    plt.close('all')

def plot_cceg_nopi():
    taskspi = ['cceg thr 1', 'cceg thr 3', 'cceg thr 5', 'cceg thr 10', 'cceg thr 25']
    tasks = ['ccegnopi thr 1', 'ccegnopi thr 3', 'ccegnopi thr 5', 'ccegnopi thr 10', 'ccegnopi thr 25']
    labels = ['1', '3', '5', '10', '25']
    labelsnopi = ['1, no prior', '3, no prior', '5, no prior', '10, no prior', '25, no prior']
    colors = [cmap(1), cmap(2), cmap(3), cmap(5), cmap(6)]
    metrics = [
        ('eval/mean_reward_return', 'Reward'),
        ('eval/mean_cost_return', 'Cost'),
        ('train/cost_rate', 'Cost Rate'),
    ]
    
    rows, cols = 2, 2
    fig, ax = plt.subplots(rows, cols, figsize=(6, 4), layout='constrained')
    
    ax[0][0].set_title('Return')
    ax[0][1].set_title('Cost Rate')

    for i in range(cols):
        ax[rows-1][i].set_xlabel(r'Env Steps (x $10^6$)')

    # MAIN PLOT
    ax[0][0].set_ylabel('PointGoal1')
    tasks1 = [f'PG1 {n}' for n in taskspi]
    lines = []
    for i, task in enumerate(tasks1):
        data = get_spowl_logs(task, metrics)
        lines.append(plot_metric(data['steps'], data['Reward'], ax[0][0], colors[i]))
        plot_metric(data['steps'], data['Cost Rate'], ax[0][1], colors[i])
    
    tasks1 = [f'PG1 {n}' for n in tasks]
    for i, task in enumerate(tasks1):
        data = get_spowl_logs(task, metrics)
        lines.append(plot_metric(data['steps'], data['Reward'], ax[0][0], colors[i], ls=':'))
        plot_metric(data['steps'], data['Cost Rate'], ax[0][1], colors[i], ls=':')
        
    ax[1][0].set_ylabel('PointGoal2')
    tasks2 = [f'PG2 {n}' for n in taskspi]
    for i, task in enumerate(tasks2):
        data = get_spowl_logs(task, metrics)
        plot_metric(data['steps'], data['Reward'], ax[1][0], colors[i])
        plot_metric(data['steps'], data['Cost Rate'], ax[1][1], colors[i])
        
    tasks2 = [f'PG2 {n}' for n in tasks]
    for i, task in enumerate(tasks2):
        data = get_spowl_logs(task, metrics)
        plot_metric(data['steps'], data['Reward'], ax[1][0], colors[i], ls=':')
        plot_metric(data['steps'], data['Cost Rate'], ax[1][1], colors[i], ls=':')
    # END MAIN PLOT

    fig.legend(lines, labels+labelsnopi, ncols=1, loc='outside center right')
    for i, j in product(range(rows), range(cols)):
        ax[i][j].set_xticks(np.arange(6) * 1e6)
        ax[i][j].set_xticklabels(['', '1', '2', '3', '4', '5'])
        ax[i][j].set_xlim(0, 5_000_000)

    plt.savefig('results.png', dpi=600)
    plt.close('all')

plot_cceg()