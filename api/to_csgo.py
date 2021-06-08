# -*- coding: utf -*-
import os
import time
import copy
import socket
import ujson
from flask import Flask, json, jsonify, request

app = Flask(__name__)


def load_container() -> dict:
    container = os.getenv('SOCKET_CONTAINER')
    if not container:
        container = {}
    else:
        container = ujson.loads(container)
    return container

def dump_container(container: dict) -> bool:
    try:
        os.environ['SOCKET_CONTAINER'] = ujson.dumps(container)
        return True
    except:
        return False

@app.route('/api/to_csgo', methods=['POST'])
def to_csgo_view():
    return jsonify({"status": "error"})


@app.route('/api/tcp_create', methods=['POST'])
def connect_tcp():
    socket_container = load_container()
    sv_remark = request.form.get("sv_remark")
    sv_host = request.form.get("sv_host")
    sv_port = request.form.get("sv_port")
    qq_group = request.form.get("qq_group")

    success = False
    if qq_group in socket_container.keys():
        for value_idx in range(len(socket_container[qq_group])):
            if socket_container[qq_group][value_idx][1] == sv_host:
                socket_container[qq_group][value_idx] = [sv_remark, sv_host, sv_port, time.time()]
                dump_container(socket_container)
                return jsonify({
                    "status": "warning",
                    "message": "tcp connect exist"
                })
        socket_container[qq_group].append([sv_remark, sv_host, sv_port, time.time()])
        success = True
    else:
        socket_container[qq_group] = [[sv_remark, sv_host, sv_port, time.time()]]
        success = True

    if success:
        dump_container(socket_container)
        return jsonify({
            "status": "ok",
            "message": "[success] tcp connect created"
        })
    else:
        return jsonify({"status": "error"})


@app.route('/api/tcp_close', methods=['POST'])
def close_tcp():
    socket_container = load_container()
    sv_remark = request.form.get("sv_remark")
    sv_host = request.form.get("sv_host")
    qq_group = request.form.get("qq_group")

    if qq_group in socket_container.keys():
        for value_idx in range(len(socket_container[qq_group])):
            if socket_container[qq_group][value_idx][1] == sv_host:
                del socket_container[qq_group][value_idx]
                dump_container(socket_container)
                return jsonify({
                    "status": "ok",
                    "message": "[success] tcp connect closed"
                })

    return jsonify({
        "status": "warning",
        "message": "tcp connect not exist"
    })

@app.route('/api/socket_info', methods=['GET'])
def socket_info():
    web_token = request.args.get('web_token')
    access_token = os.getenv('ACCESS_TOKEN')
    if web_token != access_token:
        return jsonify({
            "status": "error",
            "message": "token invalid"
        })
    socket_container = load_container()
    return jsonify({
        "status": "ok",
        "result": socket_container
    })

@app.route('/api/socket_refresh', methods=['GET'])
def socket_refresh():
    web_token = request.args.get('web_token')
    access_token = os.getenv('ACCESS_TOKEN')
    if web_token != access_token:
        return jsonify({
            "status": "error",
            "message": "token invalid"
        })

    socket_container = load_container()
    if len(socket_container.keys()) == 0:
        return jsonify({
            "status": "ok",
            "message": "empty session"
        })

    old_socket_container = copy.deepcopy(socket_container)
    for mykey in list(socket_container.keys()):
        if len(socket_container[mykey]) == 0:
            continue
        for myvalue_idx in range(len(socket_container[mykey])):
            if time.time() - float(socket_container[mykey][myvalue_idx][3]) >= 24 * 60 * 60:
                del socket_container[mykey][myvalue_idx]
        if len(socket_container[mykey]) == 0:
            socket_container.pop(mykey)

    dump_container(socket_container)
    return jsonify({
        "status": "ok",
        "old_session": old_socket_container,
        "new_session": socket_container
    })