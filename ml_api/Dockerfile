FROM thespaghettidetective/ml_api:base-1.1
WORKDIR /app
EXPOSE 3333

ADD . /app
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

RUN wget --quiet -O model/model.weights $(cat model/model.weights.url | tr -d '\r')

CMD bash -c "gunicorn --bind 0.0.0.0:3333 --workers 1 wsgi"