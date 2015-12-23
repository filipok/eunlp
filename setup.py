import os
from setuptools import setup

with open(os.path.join(os.path.dirname(__file__), 'README.rst')) as readme:
    README = readme.read()

# allow setup.py to be run from any path
os.chdir(os.path.normpath(os.path.join(os.path.abspath(__file__), os.pardir)))

setup(
    name='align',
    version='0.1',
    packages=['align'],
    include_package_data=True,
    description='Align EU legislation.',
    long_description=README,
    author='Filip Gadiuta',
    author_email='filip.gadiuta@gmail.com',
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: Python',
        'Programming Language :: Python :: 2.7',
        'Topic :: Text Processing :: Linguistic',
    ],
    install_requires=['nltk', 'beautifulsoup4', 'lxml'],
)