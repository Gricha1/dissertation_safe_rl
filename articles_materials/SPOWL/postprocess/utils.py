import pandas as pd
from collections import defaultdict
import numpy as np


def ma(x, w):
    return np.convolve(x, np.ones(w)/w, mode='valid')


def get_spowl_logs(name, metrics):
    dt = 50_000
    print(f'Get SPOWL logs: {name}')
    new_name = name.replace(' ', '_')
    paths = [f'data/spowl/{new_name}/seed_{i}.jsonl' for i in range(3)]
    
    all_data = defaultdict(list)
    for path in paths:
        df = pd.read_json(path, lines=True)
        for met in metrics:
            if met[0] in df.keys():
                y = df[met[0]].to_numpy()
                all_data[met[1]].append(y)

    all_data = {k: np.stack(v, 0) for k, v in all_data.items()}
    shapes = np.array([v.shape for v in all_data.values()])
    assert np.all(shapes == shapes[0])
    all_data['steps'] = dt * (np.arange(shapes[0, 1]) + 1)
    return all_data


def plot_metric(x, y, ax, color, base=None, window=5, **kw):
    mean = y.mean(0)
    if base is not None:
        base_mean = base.mean(0)
        mean -= base_mean
    std = y.std(0)
    step = x
    line, = ax.plot(ma(step, window), ma(mean, window), color=color, **kw)
    ax.fill_between(ma(step, window), ma(mean+std, window), ma(mean-std, window), facecolor=color, alpha=0.2)
    return line
