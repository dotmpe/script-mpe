#!/usr/bin/env python3
# vim:fenc=utf-8
#
# Copyright © 2026 hari <hari@t470p>
#
# Distributed under terms of the MIT license.
"""

"""
import os, sys
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import make_pipeline
from sklearn.model_selection import train_test_split
import joblib

def load_data(root_dir):
    data = []
    for category in os.listdir(root_dir):
        cat_path = os.path.join(root_dir, category)
        if os.path.isdir(cat_path):
            for fname in os.listdir(cat_path):
                fpath = os.path.join(cat_path, fname)
                if os.path.isfile(fpath):
                    # Features: filename + optional content snippet
                    text = fname
                    #try:
                    #    if fpath.endswith(('.txt', '.md', '.csv', '.json')):  # add more extensions
                    #        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                    #            text += " " + f.read()[:5000]  # limit to avoid huge files
                    #except:
                    #    pass
                    data.append({'text': text, 'label': category})
    return pd.DataFrame(data)

def read_data():
    data = []
    for line in sys.stdin:
        label, text = line.split('\t', 1)
        data.append({'text': text, 'label': label})
    return pd.DataFrame(data)


if __name__ == '__main__':
    args = sys.argv[1:]
    print(args)
    if not args: args = [ '--stdin' ]
    if args[0] == '--stdin':
        df = read_data()
    elif args[0] == '--walk':
        df = load_data(args[1])
    else:
        sys.exit(2)

    X_train, X_test, y_train, y_test = train_test_split(df['text'], df['label'], test_size=0.2)

    # Pipeline: vectorize + classifier
    model = make_pipeline(TfidfVectorizer(stop_words='english', max_features=10000), MultinomialNB())
    model.fit(X_train, y_train)

    print("Accuracy:", model.score(X_test, y_test))
    modelname = os.getenv('SCIKIT_MODELNAME', 'scikit_learn.pkl')
    joblib.dump(model, modelname)
